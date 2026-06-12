Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

Write-Host "Auto-confirmer v2 running - clicking Yes on all Confirm File Delete dialogs..."
$confirmed = 0

while ($true) {
    Start-Sleep -Milliseconds 150

    $root    = [System.Windows.Automation.AutomationElement]::RootElement
    $dlgCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty, "Confirm File Delete")
    $dialogs = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $dlgCond)

    foreach ($dlg in $dialogs) {
        # Find the Yes pane (ControlType.Pane with Name Yes)
        $yesCond = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, "Yes")
        $yesEl = $dlg.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $yesCond)

        if ($yesEl) {
            try {
                # Try LegacyIAccessible DoDefaultAction first
                $legacyPattern = $yesEl.GetCurrentPattern(
                    [System.Windows.Automation.LegacyIAccessiblePattern]::Pattern)
                $legacyPattern.DoDefaultAction()
                $confirmed++
            } catch {
                try {
                    # Fallback: click center of bounding rect
                    $rect = $yesEl.Current.BoundingRectangle
                    $cx   = [int]($rect.X + $rect.Width  / 2)
                    $cy   = [int]($rect.Y + $rect.Height / 2)
                    Add-Type @"
using System; using System.Runtime.InteropServices;
public class Clicker {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint d, int x, int y, uint data, int info);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    public const uint MOUSEEVENTF_LEFTUP   = 0x04;
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, x, y, 0, 0);
        mouse_event(MOUSEEVENTF_LEFTUP,   x, y, 0, 0);
    }
}
"@
                    [Clicker]::Click($cx, $cy)
                    $confirmed++
                } catch {}
            }
            if ($confirmed % 50 -eq 0 -and $confirmed -gt 0) {
                Write-Host "  Auto-confirmed $confirmed dialogs..."
            }
        }
    }
}
