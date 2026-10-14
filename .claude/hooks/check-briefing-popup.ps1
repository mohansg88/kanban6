# Claude Code PostToolUse hook (project level).
# After Claude edits index.html, confirm the security briefing popup is still wired up:
# the dialog markup, the 10 second delay, and the call that starts the timer.
# Exit 2 sends the message back to Claude so it can restore the popup.
# Input: the hook JSON on stdin. Output: nothing on success.

$raw = [Console]::In.ReadToEnd()
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

$path = $payload.tool_input.file_path
if (-not $path -or -not $path.EndsWith("index.html")) { exit 0 }
if (-not (Test-Path $path)) { exit 0 }

$html = Get-Content $path -Raw
$missing = @()
if ($html -notmatch 'id="briefingDialog"')       { $missing += 'the <dialog id="briefingDialog"> markup' }
if ($html -notmatch 'delayMs:\s*10000')          { $missing += 'BRIEFING.delayMs set to 10000 (10 seconds)' }
if ($html -notmatch 'setTimeout\(showBriefing')  { $missing += 'the setTimeout(showBriefing, ...) call in setupBriefing()' }
if ($html -notmatch 'setupBriefing\(\);')        { $missing += 'the setupBriefing() call in init()' }
if ($html -notmatch 'Town Hall room')            { $missing += 'the "Town Hall room" location' }

if ($missing.Count -gt 0) {
  [Console]::Error.WriteLine("index.html no longer has the security briefing popup (10 second notice for next Monday 10:00 am, Town Hall room). Missing: " + ($missing -join "; ") + ". Restore it.")
  exit 2
}
exit 0
