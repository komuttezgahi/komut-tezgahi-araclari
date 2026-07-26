#Requires AutoHotkey v2.0
#SingleInstance Off
#MaxThreadsPerHotkey 1

; Flow Auto Generate
; ------------------
; Desteklenen TXT biçimleri:
;   1) FLOW PROMPT: satırından sonraki ilk boş olmayan satır
;      (FLOW PROMPT: prompt metni biçimi de kabul edilir)
;   2) Dosyada hiç FLOW PROMPT: yoksa, her boş olmayan satır bir prompt
;
; Bu script ekran koordinatlarıyla çalışır. Flow'un üretimi gerçekten kabul
; ettiğini API/DOM üzerinden doğrulamaz. İlk kullanımı küçük bir TXT ile test edin.

SendMode("Input")
CoordMode("Mouse", "Client")

global APP_NAME := "Flow Auto Generate"
global prompts := []
global promptMode := ""
global txtPath := ""
global progressFile := ""
global logFile := ""
global progressNotice := ""

global promptX := -1
global promptY := -1
global generateX := -1
global generateY := -1

global targetHwnd := 0
global targetPid := 0
global targetProcess := ""
global targetClass := ""
global targetWidth := 0
global targetHeight := 0
global targetDpi := 0
global targetTitleToken := "Flow"
global targetWindowTitle := ""

global delayMs := 20000
global stopFlag := false
global running := false
global nextIndex := 1

global clipboardBackup := 0
global clipboardBackupValid := false
global mutexHandle := 0

global localStateRoot := EnvGet("LOCALAPPDATA")
if (localStateRoot = "")
    localStateRoot := A_AppData
global stateDir := localStateRoot "\FlowAutoGenerate"

OnExit(Cleanup)

; Kodun yalnızca parse edilmesini sağlayan, kullanıcı arayüzü açmayan test modu.
if (A_Args.Length >= 1 && A_Args[1] = "--syntax-check")
    ExitApp(0)

if (A_Args.Length >= 1 && A_Args[1] = "--self-test") {
    testDir := (A_Args.Length >= 2) ? A_Args[2] : A_ScriptDir
    RunSelfTests(testDir)
    ExitApp(0)
}

AcquireInstanceLock()
Init()

^F1::SetPromptPoint()
^F2::SetGeneratePoint()
^F8::StartAutomation()
^F9::StopAutomation()

Init() {
    global prompts, promptMode, txtPath, progressFile, logFile, progressNotice
    global delayMs, nextIndex, stateDir, APP_NAME

    try {
        DirCreate(stateDir)
        logFile := stateDir "\flow_auto_generate.log"
        RotateLogIfNeeded()

        txtPath := FileSelect(
            1,
            A_Desktop,
            "Prompt TXT dosyasını seç",
            "Text Documents (*.txt)"
        )
        if !txtPath
            ExitApp()

        fileName := ""
        fileDir := ""
        extension := ""
        nameNoExt := ""
        drive := ""
        SplitPath(txtPath, &fileName, &fileDir, &extension, &nameNoExt, &drive)
        if (StrLower(extension) != "txt")
            throw Error("Seçilen dosyanın uzantısı .txt olmalı.")

        loadResult := LoadPromptsFromFile(txtPath)
        prompts := loadResult.Items
        promptMode := loadResult.Mode

        if (prompts.Length = 0)
            throw Error("TXT dosyasında kullanılabilir prompt bulunamadı.")

        progressFile := BuildProgressPath(txtPath, prompts)
        nextIndex := LoadProgress(prompts.Length)
        delayMs := AskDelay()

        if (nextIndex = prompts.Length + 1)
            resumeText := "`nDurum: Bu prompt seti daha önce tamamlanmış."
        else if (nextIndex > 1)
            resumeText := "`nKayıtlı devam noktası: " nextIndex
        else
            resumeText := ""

        if (progressNotice != "")
            resumeText .= "`n" progressNotice

        firstPreview := PromptPreview(prompts[1])
        lastPreview := PromptPreview(prompts[prompts.Length])
        modeExplanation := (promptMode = "FLOW PROMPT:")
            ? "Her FLOW PROMPT: işaretinden sonraki ilk boş olmayan satır alınır."
            : "Her boş olmayan satır ayrı bir prompt kabul edilir."

        confirmation := MsgBox(
            "Toplam prompt: " prompts.Length "`n"
            . "Algılanan biçim: " promptMode "`n"
            . modeExplanation resumeText "`n`n"
            . "İlk prompt: " firstPreview "`n"
            . "Son prompt: " lastPreview "`n"
            . "UYARI: Bu iki önizleme ekran kaydında da görünür.`n`n"
            . "Hazırlık:`n"
            . "1) Flow'da yeni projeyi aç ve model/oran/adet ayarlarını yap.`n"
            . "2) Kullanacağın tarayıcı penceresini istediğin boyuta getir.`n"
            . "3) Flow sekmesi öndeyken prompt alanına gel ve Ctrl+F1'e bas.`n"
            . "4) Generate düğmesine gel ve Ctrl+F2'ye bas.`n"
            . "5) Ctrl+F8'e bas; başlangıç numarasını onayla ve bilgisayarı bırak.`n"
            . "6) Durdurma isteği: Ctrl+F9.`n`n"
            . "ÖNCE KÜÇÜK BİR TXT İLE TEST ET. Dosya UTF-8 olmalı. Çalışırken fare/klavyeyi kullanma, "
            . "başka sekmeye geçme ve Flow üstünde açılır pencere bırakma.`n`n"
            . "Çalışırken Windows açık ve kilitsiz, Flow sekmesi görünür kalmalı. "
            . "Pencere boyutu, tarayıcı zoom'u ve sayfa kaydırması değiştirilmemeli. "
            . "Script bilgisayarın otomatik uyumasını engeller; manuel kilit, kapak kapatma "
            . "veya Windows yeniden başlatmasını engelleyemez.`n`n"
            . "Promptlar yapıştırma için kısa süreliğine Windows panosuna yazılır. "
            . "Pano geçmişi veya cihazlar arası pano eşitleme açıksa kaydedilebilir.`n`n"
            . "Bu liste ve hazırlık doğruysa Tamam'a bas.",
            APP_NAME,
            "OKCancel"
        )
        if (confirmation = "Cancel")
            ExitApp()

        LogEvent("READY prompts=" prompts.Length " mode=" promptMode)
    } catch as err {
        MsgBox("Başlatma hatası:`n`n" err.Message, APP_NAME)
        ExitApp(1)
    }
}

AskDelay() {
    global APP_NAME

    Loop {
        result := InputBox(
            "Generate tıklamasından sonra beklenecek süreyi saniye olarak gir.`n"
            . "Flow ve bağlantın yavaşsa yüksek bir değer kullan. Aralık: 5-3600.",
            "Her Üretim Sonrası Bekleme",
            "w430 h175",
            "20"
        )

        if (result.Result = "Cancel")
            ExitApp()

        raw := StrReplace(Trim(result.Value), ",", ".")
        try seconds := Number(raw)
        catch {
            MsgBox("Geçerli bir sayı gir.", APP_NAME)
            continue
        }

        if (seconds < 5 || seconds > 3600) {
            MsgBox("Bekleme süresi 5 ile 3600 saniye arasında olmalı.", APP_NAME)
            continue
        }

        return Round(seconds * 1000)
    }
}

LoadPromptsFromFile(path) {
    text := FileRead(path, "UTF-8")
    text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
    lines := StrSplit(text, "`n")
    items := []
    hasMarker := false

    for rawLine in lines {
        clean := CleanPromptLine(rawLine)
        if RegExMatch(clean, "i)^FLOW PROMPT:\s*(.*)$") {
            hasMarker := true
            break
        }
    }

    if hasMarker {
        waitingForPrompt := false
        markerLine := 0

        for lineNumber, rawLine in lines {
            clean := CleanPromptLine(rawLine)

            if RegExMatch(clean, "i)^FLOW PROMPT:\s*(.*)$", &match) {
                if waitingForPrompt
                    throw Error("Satır " markerLine " için prompt yok.")

                inlinePrompt := Trim(match[1])
                if (inlinePrompt != "") {
                    items.Push(inlinePrompt)
                    waitingForPrompt := false
                } else {
                    waitingForPrompt := true
                    markerLine := lineNumber
                }
                continue
            }

            if (waitingForPrompt && clean != "") {
                items.Push(clean)
                waitingForPrompt := false
            }
        }

        if waitingForPrompt
            throw Error("Satır " markerLine " için prompt yok.")

        return {Items: items, Mode: "FLOW PROMPT:"}
    }

    for rawLine in lines {
        clean := CleanPromptLine(rawLine)
        if (clean != "")
            items.Push(clean)
    }

    return {Items: items, Mode: "Her boş olmayan satır = 1 prompt"}
}

CleanPromptLine(line) {
    line := StrReplace(line, Chr(0xFEFF), "")
    return Trim(line, " `t`r`n")
}

BuildProgressPath(path, items) {
    global stateDir
    signature := "schema=2|" StrLower(path) "|count=" items.Length
    for item in items
        signature .= "|" StrLen(item) ":" item

    ; İki farklı 32-bit özet birleştirilir. Böylece yalnız mtime/boyuta
    ; güvenilmez ve aynı içerik yeniden kaydedildiğinde devam noktası korunur.
    key := HashString(signature, 0x811C9DC5)
        . HashString("flow-state-v2|" signature, 0xA5B35705)
    return stateDir "\" key ".progress.txt"
}

HashString(text, seed := 2166136261) {
    hash := seed
    for character in StrSplit(text)
        hash := ((hash ^ Ord(character)) * 16777619) & 0xFFFFFFFF
    return Format("{:08X}", hash)
}

LoadProgress(maxIndex) {
    global progressFile, progressNotice

    progressNotice := ""

    if !FileExist(progressFile)
        return 1

    try {
        saved := Trim(FileRead(progressFile, "UTF-8"), " `t`r`n")
        if RegExMatch(saved, "^\d+$") {
            index := Integer(saved)
            if (index >= 1 && index <= maxIndex + 1)
                return index
        }
        progressNotice := "UYARI: İlerleme kaydı geçersizdi; başlangıç 1 olarak ayarlandı."
    } catch as err {
        LogEvent("WARN progress_read_failed " OneLine(err.Message))
        progressNotice := "UYARI: İlerleme kaydı okunamadı; başlangıç 1 olarak ayarlandı."
    }

    return 1
}

SetPromptPoint() {
    global running, targetHwnd, targetPid, targetProcess, targetClass
    global targetWidth, targetHeight, targetDpi
    global promptX, promptY, generateX, generateY
    global targetTitleToken, targetWindowTitle, APP_NAME

    if running {
        ShowTemporaryTip("Çalışırken yeniden kalibrasyon yapılamaz.")
        return
    }

    activeHwnd := WinExist("A")
    MouseGetPos(&x, &y, &hoverHwnd)

    if (!activeHwnd || hoverHwnd != activeHwnd) {
        MsgBox(
            "Flow sekmesinin bulunduğu pencereyi önce etkinleştir; ardından fare prompt alanındayken Ctrl+F1'e bas.",
            APP_NAME
        )
        return
    }

    try {
        GetClientSize(activeHwnd, &width, &height)
        if !PointIsInside(x, y, width, height)
            throw Error("Seçilen prompt noktası pencerenin istemci alanı dışında.")

        spec := WindowSpec(activeHwnd)
        windowTitle := WinGetTitle(spec)
        if !InStr(windowTitle, targetTitleToken, false)
            throw Error(
                "Etkin pencerenin başlığında '" targetTitleToken "' bulunamadı. "
                . "Önce gerçek Google Flow sekmesini etkinleştir."
            )

        targetHwnd := activeHwnd
        targetPid := WinGetPID(spec)
        targetProcess := WinGetProcessName(spec)
        targetClass := WinGetClass(spec)
        targetWindowTitle := windowTitle
        targetWidth := width
        targetHeight := height
        targetDpi := GetWindowDpi(activeHwnd)

        promptX := x
        promptY := y
        generateX := -1
        generateY := -1

        ShowTemporaryTip(
            "Prompt alanı kaydedildi: " promptX ", " promptY
            . "`nŞimdi Generate düğmesinde Ctrl+F2."
        )
    } catch as err {
        ResetCalibration()
        MsgBox("Prompt noktası kaydedilemedi:`n`n" err.Message, APP_NAME)
    }
}

SetGeneratePoint() {
    global running, targetHwnd, targetWidth, targetHeight
    global promptX, promptY, generateX, generateY, APP_NAME

    if running {
        ShowTemporaryTip("Çalışırken yeniden kalibrasyon yapılamaz.")
        return
    }

    if !targetHwnd {
        MsgBox("Önce prompt alanında Ctrl+F1'e bas.", APP_NAME)
        return
    }

    activeHwnd := WinExist("A")
    MouseGetPos(&x, &y, &hoverHwnd)

    if (activeHwnd != targetHwnd || hoverHwnd != targetHwnd) {
        MsgBox(
            "Generate noktası prompt alanıyla aynı etkin pencereden seçilmeli. "
            . "Gerekirse prompt alanını Ctrl+F1 ile yeniden kaydet.",
            APP_NAME
        )
        return
    }

    try {
        VerifyTargetIdentity()
        GetClientSize(targetHwnd, &width, &height)
        if (Abs(width - targetWidth) > 3 || Abs(height - targetHeight) > 3)
            throw Error("Pencere boyutu ilk kalibrasyondan sonra değişmiş. Ctrl+F1 ile yeniden başla.")
        if !PointIsInside(x, y, width, height)
            throw Error("Seçilen Generate noktası pencerenin istemci alanı dışında.")

        generateX := x
        generateY := y
        ShowTemporaryTip(
            "Kalibrasyon tamamlandı.`nPrompt: " promptX ", " promptY
            . " | Generate: " generateX ", " generateY
            . "`nBaşlatmak için Ctrl+F8."
        )
    } catch as err {
        MsgBox("Generate noktası kaydedilemedi:`n`n" err.Message, APP_NAME)
    }
}

StartAutomation() {
    global running, stopFlag, nextIndex, prompts
    global promptX, promptY, generateX, generateY, targetHwnd
    global clipboardBackupValid
    global APP_NAME

    if running {
        ShowTemporaryTip("Otomasyon zaten çalışıyor.")
        return
    }

    if (!targetHwnd || promptX < 0 || promptY < 0 || generateX < 0 || generateY < 0) {
        MsgBox("Önce Ctrl+F1 ve Ctrl+F2 ile iki noktayı kalibre et.", APP_NAME)
        return
    }

    if (clipboardBackupValid && !RestoreClipboard(false)) {
        MsgBox(
            "Önceki çalışmadan kalan pano yedeği geri yüklenemedi. "
            . "Orijinal panoyu kaybetmemek için yeni çalışma başlatılmadı. Scripti kapatıp tekrar dene.",
            APP_NAME
        )
        return
    }

    if (nextIndex = prompts.Length + 1) {
        restartAnswer := MsgBox(
            "Bu prompt seti daha önce tamamlanmış görünüyor.`n`n"
            . "Tüm promptları 1 numaradan yeniden göndermek istiyor musun?",
            APP_NAME,
            "YesNo"
        )
        if (restartAnswer != "Yes")
            return
        defaultIndex := 1
    } else {
        defaultIndex := (nextIndex >= 1 && nextIndex <= prompts.Length) ? nextIndex : 1
    }

    startIndex := AskStartIndex(defaultIndex, prompts.Length)
    if !startIndex
        return

    nextIndex := startIndex
    stopFlag := false
    running := true
    status := "error"
    errorMessage := ""

    try {
        if !SetAwake(true)
            throw Error("Windows uyku engeli etkinleştirilemedi. Güç ayarlarını kontrol et.")

        EnsureTargetReady()
        if !CountdownToStart(3) {
            status := "stopped"
        } else {
            LogEvent("RUN_START index=" nextIndex " total=" prompts.Length)
            status := RunLoop()
        }
    } catch as err {
        errorMessage := err.Message
        LogEvent("ERROR index=" nextIndex " " OneLine(errorMessage))
        status := "error"
    } finally {
        RestoreClipboard(false)
        SetAwake(false)
        running := false
        RemoveToolTip()
    }

    switch status {
        case "complete":
            MsgBox(
                "Tüm promptlar gönderildi varsayıldı.`n`n"
                . "Not: Koordinat tabanlı otomasyon Flow'un sunucu tarafında her üretimi kabul ettiğini kesin doğrulayamaz. "
                . "Sonuçları ve eksik üretimleri kontrol et.",
                APP_NAME
            )
        case "stopped":
            if (nextIndex > prompts.Length) {
                MsgBox(
                    "Durdurma isteği son prompt gönderildikten sonra işlendi. "
                    . "Liste tamamlandı varsayılıyor; sonuçları Flow'da kontrol et.",
                    APP_NAME
                )
            } else {
                MsgBox(
                    "Otomasyon güvenli bir kontrol noktasında durduruldu.`n"
                    . "Ctrl+F8 ile yeniden başlatınca önerilen devam noktası: " nextIndex,
                    APP_NAME
                )
            }
        case "error":
            MsgBox(
                "Otomasyon yanlış işlem yapmamak için güvenli biçimde durdu:`n`n"
                . errorMessage "`n`nKalibrasyonu ve Flow ekranını kontrol et.",
                APP_NAME
            )
    }
}

AskStartIndex(defaultIndex, maxIndex) {
    global APP_NAME

    Loop {
        result := InputBox(
            "Kaçıncı prompttan başlasın? (1-" maxIndex ")",
            "Başlangıç Promptu",
            "w360 h145",
            String(defaultIndex)
        )

        if (result.Result = "Cancel")
            return 0

        rawIndex := Trim(result.Value)
        if !RegExMatch(rawIndex, "^\d+$") {
            MsgBox("Geçerli bir tam sayı gir.", APP_NAME)
            continue
        }
        index := Integer(rawIndex)

        if (index < 1 || index > maxIndex) {
            MsgBox("Başlangıç numarası 1 ile " maxIndex " arasında olmalı.", APP_NAME)
            continue
        }

        return index
    }
}

CountdownToStart(seconds) {
    global stopFlag

    Loop seconds {
        if stopFlag
            return false
        remaining := seconds - A_Index + 1
        ToolTip("Otomasyon " remaining " saniye sonra başlayacak...`nDurdurma isteği: Ctrl+F9.")
        Sleep(1000)
    }

    RemoveToolTip()
    return !stopFlag
}

RunLoop() {
    global prompts, nextIndex, stopFlag

    while (nextIndex <= prompts.Length) {
        if stopFlag
            return "stopped"

        currentIndex := nextIndex
        if !SubmitPrompt(prompts[currentIndex], currentIndex)
            return "stopped"

        ; Generate tıklandıktan sonra bu değer "gönderildi varsayılan" noktadır.
        nextIndex := currentIndex + 1
        SaveProgressAtomic(nextIndex)
        LogEvent("SUBMITTED index=" currentIndex " total=" prompts.Length)

        if !WaitForNextPrompt(currentIndex, prompts.Length)
            return "stopped"
    }

    SaveProgressAtomic(prompts.Length + 1)
    LogEvent("RUN_COMPLETE total=" prompts.Length)
    return "complete"
}

SubmitPrompt(prompt, index) {
    global stopFlag, promptX, promptY, generateX, generateY, prompts

    EnsureTargetReady()
    if stopFlag
        return false

    ; Prompt alanına odaklan ve mevcut metni seç. Backspace kullanılmaz;
    ; yapıştırma, seçili metni tek adımda değiştirir.
    Click(promptX, promptY)
    Sleep(250)

    EnsureTargetReady()
    if stopFlag
        return false
    Send("^a")
    Sleep(120)

    if !PastePrompt(prompt)
        return false

    ; Generate öncesinde pencere kimliği ve odak son kez doğrulanır.
    EnsureTargetReady()
    if stopFlag
        return false

    Click(generateX, generateY)
    Sleep(350)

    ToolTip(
        "Gönderildi varsayıldı: " index "/" prompts.Length
        . "`nFlow yanıtı için bekleniyor... | Durdurma: Ctrl+F9"
    )
    return true
}

PastePrompt(prompt) {
    global stopFlag

    CaptureClipboard()
    try {
        SetClipboardText(prompt)
        EnsureTargetReady()
        if stopFlag
            return false

        Send("^v")
        Sleep(300)

        EnsureTargetReady()
        if stopFlag
            return false

        return true
    } finally {
        RestoreClipboard(true)
    }
}

CaptureClipboard() {
    global clipboardBackup, clipboardBackupValid
    lastError := ""

    if clipboardBackupValid
        throw Error(
            "Önceki pano yedeği hâlâ bekliyor. Orijinal panoyu ezmemek için yeni pano yakalanmadı."
        )

    Loop 5 {
        try {
            clipboardBackup := ClipboardAll()
            clipboardBackupValid := true
            return
        } catch as err {
            lastError := err.Message
            Sleep(150)
        }
    }

    throw Error("Mevcut pano yedeklenemedi: " lastError)
}

SetClipboardText(text) {
    lastError := ""

    Loop 5 {
        try {
            A_Clipboard := ""
            A_Clipboard := text
            if ClipWait(1)
                return
            lastError := "Pano zaman aşımına uğradı."
        } catch as err {
            lastError := err.Message
        }
        Sleep(150)
    }

    throw Error("Prompt panoya hazırlanamadı: " lastError)
}

RestoreClipboard(throwOnFailure := false) {
    global clipboardBackup, clipboardBackupValid

    if !clipboardBackupValid
        return true

    lastError := ""
    Loop 5 {
        try {
            A_Clipboard := clipboardBackup
            clipboardBackup := 0
            clipboardBackupValid := false
            return true
        } catch as err {
            lastError := err.Message
            Sleep(150)
        }
    }

    if throwOnFailure
        throw Error("Önceki pano içeriği geri yüklenemedi: " lastError)
    return false
}

WaitForNextPrompt(currentIndex, total) {
    global delayMs, stopFlag
    remaining := delayMs
    lastShownSecond := -1

    while (remaining > 0) {
        if stopFlag
            return false

        secondsLeft := Ceil(remaining / 1000)
        if (secondsLeft != lastShownSecond) {
            if (currentIndex = total) {
                waitText := "Son üretim için " secondsLeft " saniye daha bekleniyor"
            } else {
                waitText := "Sıradaki prompta " secondsLeft " saniye"
            }
            ToolTip(
                "Gönderildi varsayıldı: " currentIndex "/" total
                . "`n" waitText " | Durdurma: Ctrl+F9"
            )
            lastShownSecond := secondsLeft
        }

        slice := Min(200, remaining)
        Sleep(slice)
        remaining -= slice
    }

    return !stopFlag
}

StopAutomation() {
    global running, stopFlag

    if !running {
        ShowTemporaryTip("Otomasyon çalışmıyor.")
        return
    }

    stopFlag := true
    ToolTip("Durdurma istendi. Mevcut kısa adım bittikten sonraki kontrol noktasında duracak...")
}

EnsureTargetReady() {
    global targetHwnd, targetWidth, targetHeight, targetDpi
    global promptX, promptY, generateX, generateY

    VerifyTargetIdentity()
    spec := WindowSpec(targetHwnd)

    if (WinGetMinMax(spec) = -1)
        WinRestore(spec)

    WinActivate(spec)
    if !WinWaitActive(spec, , 2)
        throw Error("Kalibre edilen Flow penceresi etkinleştirilemedi.")

    ; Etkinleştirmeden sonra kimlik tekrar kontrol edilir.
    VerifyTargetIdentity()
    if !WinActive(spec)
        throw Error("Flow penceresi etkin değil; hiçbir giriş gönderilmedi.")

    GetClientSize(targetHwnd, &width, &height)
    if (Abs(width - targetWidth) > 3 || Abs(height - targetHeight) > 3)
        throw Error("Flow penceresinin boyutu değişmiş. Ctrl+F1/Ctrl+F2 ile yeniden kalibrasyon gerekli.")

    currentDpi := GetWindowDpi(targetHwnd)
    if (targetDpi && currentDpi && currentDpi != targetDpi)
        throw Error("Flow penceresinin ekran ölçeği/DPI değeri değişmiş. Yeniden kalibrasyon gerekli.")

    if !PointIsInside(promptX, promptY, width, height)
        throw Error("Prompt koordinatı artık pencere içinde değil.")
    if !PointIsInside(generateX, generateY, width, height)
        throw Error("Generate koordinatı artık pencere içinde değil.")
}

VerifyTargetIdentity() {
    global targetHwnd, targetPid, targetProcess, targetClass, targetWindowTitle

    if !targetHwnd
        throw Error("Flow penceresi henüz kalibre edilmedi.")

    spec := WindowSpec(targetHwnd)
    if !WinExist(spec)
        throw Error("Kalibre edilen Flow penceresi kapatılmış.")

    try {
        if (WinGetPID(spec) != targetPid)
            throw Error("Hedef pencerenin işlem kimliği değişmiş.")
        if (WinGetProcessName(spec) != targetProcess)
            throw Error("Hedef pencerenin uygulaması değişmiş.")
        if (WinGetClass(spec) != targetClass)
            throw Error("Hedef pencerenin sınıfı değişmiş.")
        currentTitle := WinGetTitle(spec)
        if !(currentTitle == targetWindowTitle)
            throw Error(
                "Tarayıcı sekmesinin başlığı kalibrasyondan sonra değişmiş. "
                . "Doğru Flow sekmesine dönüp Ctrl+F1/Ctrl+F2 ile yeniden kalibre et."
            )
    } catch as err {
        throw Error("Flow pencere kimliği doğrulanamadı: " err.Message)
    }
}

GetClientSize(hwnd, &width, &height) {
    x := 0
    y := 0
    width := 0
    height := 0
    WinGetClientPos(&x, &y, &width, &height, WindowSpec(hwnd))
    if (width <= 0 || height <= 0)
        throw Error("Pencere istemci alanı ölçülemedi.")
}

GetWindowDpi(hwnd) {
    try return DllCall("User32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    catch
        return 0
}

PointIsInside(x, y, width, height) {
    return (x >= 0 && y >= 0 && x < width && y < height)
}

WindowSpec(hwnd) {
    return "ahk_id " hwnd
}

ResetCalibration() {
    global promptX, promptY, generateX, generateY
    global targetHwnd, targetPid, targetProcess, targetClass
    global targetWidth, targetHeight, targetDpi, targetWindowTitle

    promptX := -1
    promptY := -1
    generateX := -1
    generateY := -1
    targetHwnd := 0
    targetPid := 0
    targetProcess := ""
    targetClass := ""
    targetWindowTitle := ""
    targetWidth := 0
    targetHeight := 0
    targetDpi := 0
}

SaveProgressAtomic(index) {
    global progressFile
    pid := DllCall("Kernel32\GetCurrentProcessId", "UInt")
    tempFile := progressFile "." pid ".tmp"

    try {
        if FileExist(tempFile)
            FileDelete(tempFile)

        file := FileOpen(tempFile, "w", "UTF-8-RAW")
        try {
            file.Write(String(index) "`n")
        } finally {
            file.Close()
        }

        FileMove(tempFile, progressFile, 1)
    } catch as err {
        try {
            if FileExist(tempFile)
                FileDelete(tempFile)
        }
        throw Error("İlerleme kaydedilemedi; yeni prompta geçilmiyor: " err.Message)
    }
}

SetAwake(enable) {
    flags := enable ? 0x80000003 : 0x80000000
    try return DllCall(
        "Kernel32\SetThreadExecutionState",
        "UInt",
        flags,
        "UInt"
    ) != 0
    catch
        return false
}

AcquireInstanceLock() {
    global mutexHandle, APP_NAME

    mutexHandle := DllCall(
        "Kernel32\CreateMutex",
        "Ptr",
        0,
        "Int",
        true,
        "Str",
        "Local\FlowAutoGenerate-v2",
        "Ptr"
    )
    lastError := DllCall("Kernel32\GetLastError", "UInt")

    if !mutexHandle
        throw Error("Otomasyon kilidi oluşturulamadı.")

    if (lastError = 183) {
        DllCall("Kernel32\CloseHandle", "Ptr", mutexHandle)
        mutexHandle := 0
        MsgBox(
            "Flow Auto Generate'ın başka bir kopyası zaten açık. "
            . "Önce eski kopyayı sistem tepsisinden kapat.",
            APP_NAME
        )
        ExitApp()
    }
}

ReleaseInstanceLock() {
    global mutexHandle

    if !mutexHandle
        return

    try DllCall("Kernel32\ReleaseMutex", "Ptr", mutexHandle)
    try DllCall("Kernel32\CloseHandle", "Ptr", mutexHandle)
    mutexHandle := 0
}

RotateLogIfNeeded() {
    global logFile

    try {
        if (FileExist(logFile) && FileGetSize(logFile) > 1048576)
            FileMove(logFile, logFile ".1", 1)
    }
}

LogEvent(message) {
    global logFile
    if (logFile = "")
        return

    try FileAppend(
        FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "`t" message "`n",
        logFile,
        "UTF-8"
    )
}

OneLine(text) {
    return StrReplace(StrReplace(text, "`r", " "), "`n", " ")
}

PromptPreview(text, maxLength := 140) {
    preview := OneLine(text)
    if (StrLen(preview) <= maxLength)
        return preview
    return SubStr(preview, 1, maxLength - 1) "…"
}

ShowTemporaryTip(text) {
    ToolTip(text)
    SetTimer(RemoveToolTip, -1800)
}

RemoveToolTip() {
    ToolTip("")
}

RunSelfTests(testDir) {
    global progressFile, mutexHandle

    plainFile := testDir "\flow_auto_generate.selftest.plain.txt"
    markerFile := testDir "\flow_auto_generate.selftest.marker.txt"
    progressFile := testDir "\flow_auto_generate.selftest.progress.txt"
    testFiles := [plainFile, markerFile, progressFile]

    try {
        DeleteTestFiles(testFiles)

        FileAppend("İlk prompt`n`nİkinci prompt`n", plainFile, "UTF-8-RAW")
        plainResult := LoadPromptsFromFile(plainFile)
        AssertTest(plainResult.Items.Length = 2, "Düz satır parser prompt sayısı")
        AssertTest(plainResult.Items[1] == "İlk prompt", "Düz satır parser ilk prompt")
        AssertTest(plainResult.Items[2] == "İkinci prompt", "Düz satır parser ikinci prompt")

        FileAppend(
            "FLOW PROMPT:`nBirinci işaretli prompt`n`nFLOW PROMPT: İkinci işaretli prompt`n",
            markerFile,
            "UTF-8-RAW"
        )
        markerResult := LoadPromptsFromFile(markerFile)
        AssertTest(markerResult.Items.Length = 2, "Marker parser prompt sayısı")
        AssertTest(markerResult.Items[1] == "Birinci işaretli prompt", "Marker parser ilk prompt")
        AssertTest(markerResult.Items[2] == "İkinci işaretli prompt", "Marker parser ikinci prompt")

        SaveProgressAtomic(3)
        AssertTest(
            Trim(FileRead(progressFile, "UTF-8"), " `t`r`n") = "3",
            "Atomik ilerleme kaydı"
        )
        AssertTest(HashString("Flow") == HashString("Flow"), "İlerleme anahtarı")
        AcquireInstanceLock()
        AssertTest(mutexHandle != 0, "Tek örnek kilidi")
        ReleaseInstanceLock()
        AssertTest(SetAwake(true), "Windows uyku engeli")
        AssertTest(SetAwake(false), "Windows uyku engeli sıfırlama")
    } finally {
        ReleaseInstanceLock()
        SetAwake(false)
        DeleteTestFiles(testFiles)
    }
}

AssertTest(condition, name) {
    if !condition
        throw Error("Self-test başarısız: " name)
}

DeleteTestFiles(paths) {
    for path in paths {
        try {
            if FileExist(path)
                FileDelete(path)
        }
    }
}

Cleanup(exitReason := "", exitCode := 0) {
    RestoreClipboard(false)
    SetAwake(false)
    ReleaseInstanceLock()
    RemoveToolTip()
}
