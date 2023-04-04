GUIFunctions.AddTab("Chests")

Gui, ICScriptHub:Tab, Chests
GUIFunctions.UseThemeTextColor()
Gui, ICScriptHub:Add, Text, x15 y+15 w350, % "Note: Game needs to be open to load user data and read chests into lists."
Gui, ICScriptHub:Add, Text, x15 y+5 w350, % "Only open chests while game is closed. (Yes, this is a hassle.)"
Gui, ICScriptHub:Add, GroupBox, x15 y+15 w425 h150 vGroupBoxChestPurchase, Buy Chests: 
Gui, ICScriptHub:Add, ComboBox, xp+15 yp+15 w300 hwndChestPurchaserChestPurchaseComboBoxID vChestPurchaserChestPurchaseComboBox gChestPurchaserChestPurchaseCB
Gui, ICScriptHub:Add, Picture, x+35 h18 w18 vButtonRefreshChestPurchaser, %g_ReloadButton%
GUIFunctions.UseThemeTextColor("InputBoxTextColor")
Gui, ICScriptHub:Add, Edit, x30 y+15 w75 vChestPurchaserPurchaseCount, % "99"
GUIFunctions.UseThemeTextColor()
Gui, ICScriptHub:Add, Button, x+15 w75 vButtonChestPurchaserBuyChests, Buy

GuiControlGet, xyVal, ICScriptHub:Pos, GroupBoxChestPurchase
xyValY += 150
Gui, ICScriptHub:Add, GroupBox, x15 y%xyValY% w425 h150 vGroupBoxChestOpen, Open Chests: 
Gui, ICScriptHub:Add, ComboBox, xp+15 yp+15 w300 hwndChestPurchaserChestOpenComboBoxID vChestPurchaserChestOpenComboBox gChestPurchaserChestOpenCB
GUIFunctions.UseThemeTextColor("InputBoxTextColor")
Gui, ICScriptHub:Add, Edit, y+15 w75 vChestPurchaserChestOpenCount, % "99"
GUIFunctions.UseThemeTextColor()
Gui, ICScriptHub:Add, Button, x+15 w75 vButtonChestPurchaserOpenChests, Open

buyChestsFunc := Func("IC_ChestPurchaser_Component.BuyChests")
GuiControl, ICScriptHub: +g, ButtonChestPurchaserBuyChests, % buyChestsFunc
openChestsFunc := Func("IC_ChestPurchaser_Component.OpenChests")
GuiControl, ICScriptHub: +g, ButtonChestPurchaserOpenChests, % openChestsFunc
chestPurchaserReadChests := Func("IC_ChestPurchaser_Component.ReadChests")
GuiControl, ICScriptHub: +g, ButtonRefreshChestPurchaser, % chestPurchaserReadChests

GuiControlGet, xyVal, ICScriptHub:Pos, GroupBoxChestOpen
xyValY +=150
Gui, ICScriptHub:Add, Text, x15 y%xyValY% w350 vChestPurchaserCurrentChestCount, % "---"

g_SF.Memory.InitializeChestsIndices()
IC_ChestPurchaser_Component.ReadChests()

ControlGet, _List, List, , , ahk_id %ChestPurchaserChestOpenComboBoxID%
_List := "|" . StrReplace(_List, "`n" , "|")
g_KeyInputTimer := 0
g_KeyInputTimerDelay := 600 ; milliseconds

ChestPurchaserChestPurchaseCB(controlID, mode, key)
{
    global IC_ChestPurchaser_Component
    global g_KeyInputTimerDelay
    global g_KeyInputTimer
    g_KeyInputTimer := A_TickCount

    GuiControlGet, inputText,, %controlID%
    if(inputText == "")
    {
        IC_ChestPurchaser_Component.FilterList(controlID)
        return
    }
    fncToCallOnTimer :=  ObjBindMethod(IC_ChestPurchaser_Component, "FilterList", controlID)
    timer := Abs(g_KeyInputTimerDelay) * -1
    SetTimer, %fncToCallOnTimer%, %timer%
}

ChestPurchaserChestOpenCB(controlID, mode, key)
{
    IC_ChestPurchaser_Component.FilterList(controlID)
}

class IC_ChestPurchaser_Component
{    

    FilterList(controlID)
    {
        global _List
        global g_KeyInputTimer
        global g_KeyInputTimerDelay

        static CB_GETCOMBOBOXINFO := 0x0164
            , CB_SETMINVISIBLE   := 0x1701
            , CB_SHOWDROPDOWN    := 0x014F
            , WM_SETCURSOR       := 0x0020
            , EM_SETSEL          := 0x00B1
            , hEdit              := 0
            , CBN_EDITCHANGE     := 5
            , LastID             := 0
        timeSinceLast := A_TickCount - g_KeyInputTimer
        if (timeSinceLast < g_KeyInputTimerDelay)
            return
        g_KeyInputTimer := A_TickCount
        ; Location of edit box for this control
        if (!hEdit OR LastID != controlID)
        {
            VarSetCapacity(COMBOBOXINFO, size := 40 + A_PtrSize*3)
            NumPut(size, COMBOBOXINFO)
            SendMessage, CB_GETCOMBOBOXINFO,, &COMBOBOXINFO,, ahk_id %controlID%
            hEdit := NumGet(COMBOBOXINFO, 40 + A_PtrSize)
        }
        LastID := controlID

        items := StrSplit(_List, "|")
        items.Delete(1) ; remove first entry (null after split)     
        GuiControlGet, inputText,, %controlID%

        newComboList := ""
        count := 0
        StartTime := A_TickCount
        Loop, % items.Count()
        {
            
            if(InStr(items[A_Index], inputText, False))
            {
                newComboList .= "|" . items[A_Index]
                count++
            }
        }
        GuiControl,, %controlID%, % newComboList = "" ? "|" : newComboList
        bool := !(newComboList = "" || StrLen(inputText) < 1)
        SendMessage, CB_SHOWDROPDOWN, bool,,, ahk_id %controlID%
        SendMessage, CB_SETMINVISIBLE, count = 0 ? 1 : count > 10 ? 10 : count,,, ahk_id %controlID%
        GuiControl, Text, %hEdit%, % inputText
        SendMessage, EM_SETSEL, -2, -1,, ahk_id %hEdit%
        SendMessage, WM_SETCURSOR,,,, ahk_id %hEdit%
        return
    }

    ReadChests()
    {
        if(WinExist("ahk_exe " . g_userSettings[ "ExeName"])) ; only update when the game is open
            g_SF.Memory.OpenProcessReader()
        else
            return
        g_SF.ResetServerCall()
        size := g_SF.Memory.ReadChestDefinesSize()
        comboBoxOptions := "|"
        if(!size OR size > 3000 OR size < 0)
        {
            comboBoxOptions .= "-- Error Reading Chests --"
            GuiControl,ICScriptHub:, ChestPurchaserChestOpenComboBox, %comboBoxOptions%
            GuiControl,ICScriptHub:, ChestPurchaserChestPurchaseComboBox, %comboBoxOptions%
            return
        }
        loop, %size%
        {
            chestID := g_SF.Memory.GetChestIDBySlot(A_Index)
            chestName := g_SF.Memory.GetChestNameBySlot(A_Index)
            comboBoxOptions .= chestID . " " . chestName . "|"
            this.comboBoxOptions := comboBoxOptions.Clone()
        }
        GuiControl,ICScriptHub:, ChestPurchaserChestOpenComboBox, %comboBoxOptions%
        GuiControl,ICScriptHub:, ChestPurchaserChestPurchaseComboBox, %comboBoxOptions%
    }

    BuyChests()
    {
        global g_ServerCall
        global ChestPurchaserPurchaseCount
        global ChestPurchaserCurrentChestCount
        global ChestPurchaserChestPurchaseComboBox
        Gui,ICScriptHub:Submit, NoHide
        if(g_ServerCall == "")
        {
            MsgBox % "No user data available. Open the game and refresh chest list before continuing."
            return
        }
        splitArray := StrSplit(ChestPurchaserChestPurchaseComboBox, " ",,2)
        chestID := splitArray[1]
        chestName := splitArray[2]
        MsgBox % "Buying " . ChestPurchaserPurchaseCount . " of " . chestName . " (ID: " . chestID . ")"
        buyCount := ChestPurchaserPurchaseCount
        while(buyCount > 0)
        {
            GuiControl, ICScriptHub:, ChestPurchaserCurrentChestCount, % "Buying " buyCount " chests..."
            response := g_ServerCall.CallBuyChests( chestID, buyCount )
            if(!IsObject(response))
            {
                MsgBox % "Error purchasing chest or parsing response."
                return
            }
            if (!response.okay)
            {
                MsgBox % "Failed because " . response.failure_reason . response.fail_message
                return 
            }
            if(chestID != 152 AND chestID != 153 AND chestID != 219  AND chestID != 311 )
                buyCount -= 100
            else
                buyCount -= 1
        }
        GuiControl, ICScriptHub:, ChestPurchaserCurrentChestCount, % "Done buying!"
        MsgBox % "Done"
    }

    OpenChests()
    {
        global g_ServerCall
        global ChestPurchaserChestOpenCount
        global ChestPurchaserCurrentChestCount
        global ChestPurchaserChestOpenComboBox
        Gui,ICScriptHub:Submit, NoHide
        if(g_ServerCall == "")
        {
            MsgBox % "No user data available. Open the game and refresh chest list before continuing."
            return
        }
        splitArray := StrSplit(ChestPurchaserChestOpenComboBox, " ",,2)
        chestID := splitArray[1]
        chestName := splitArray[2]
        MsgBox % "Opening " . ChestPurchaserChestOpenCount . " of " . chestName . " (ID: " . chestID . ") Make sure the game is closed before continuing."
        openCount := ChestPurchaserChestOpenCount
        shinyCount := 0
        while(openCount > 0)
        {
            GuiControl, ICScriptHub:, ChestPurchaserCurrentChestCount, % "Opening " openCount " chests..."
            response := g_ServerCall.CallOpenChests( chestID, openCount )
            if(!IsObject(response))
            {
                MsgBox % "Error opening chest(s) or parsing response."
                return
            }
            if (!response.success)
            {
                MsgBox % "Failed because " . response.failure_reason . response.fail_message
                return 
            }
            shinyCount += g_SF.ParseChestResults(response)
            openCount -= 99
        }
        GuiControl, ICScriptHub:, ChestPurchaserCurrentChestCount, % "Done opening!"
        shinyString := "No shiny gear found."
        if(shinyCount > 0)
        {
            shinyString := "Shinies found: " . shinyCount . "`n"
            shinyString .= IC_ChestPurchaser_Component.GetShinyCountString()
        }
        MsgBox % "Done`n" . shinyString
    }

    ; Returns a string listing shinies found by champion.
    GetShinyCountString()
    {
        shnieisByChampString := ""
        shiniesByChamp := g_SharedData.ShiniesByChamp
        for champID, slots in shiniesByChamp
        {
            champName := g_SF.Memory.ReadChampNameByID(champID)
            champName := champName ? champName : champID
            shnieisByChampString .= champName . ": Slots ["
            for k,v in slots
            {
                shnieisByChampString .= k . ","
            }
            if(slots != "")
            {
                shnieisByChampString := SubStr(shnieisByChampString,1,StrLen(shnieisByChampString)-1)
            }                
            shnieisByChampString .= "]`n"
        }
        shnieisByChampString := SubStr(shnieisByChampString, 1, StrLen(shnieisByChampString)-1)
        return shnieisByChampString
    }
}