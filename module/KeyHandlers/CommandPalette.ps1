function CommandPalette {
    param(
        [System.Nullable[System.ConsoleKeyInfo]] $key,
        [object] $arg
    )
    end {
        # Save the current buffer, cursor position, selection range and selection command count to
        # be restored after the command is found.
        function ExportState {
            $start = $length = $cursor = $inputBuffer = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$inputBuffer, [ref]$cursor)
            [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$start, [ref]$length)
            if ($start -ne -1) {
                $selectionState = [PSCustomObject]@{
                    Start    = $start
                    End      = $start + $length
                    Commands = $instance.GetType().
                        GetField('_visualSelectionCommandCount', $instanceFlags).
                        GetValue($instance)
                }
            }
            return [PSCustomObject]@{
                PSTypeName  = 'PSReadLineBufferState'
                InputBuffer = $inputBuffer
                CursorIndex = $cursor
                Selection   = $selectionState
            }
        }

        # Import inital state after command is found.
        function ImportState([PSTypeName('PSReadLineBufferState')] $state) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

            $promptBuffer.Clear()

            if ($state.InputBuffer) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($state.InputBuffer)
            }

            if ($state.Selection) {
                $start = $state.Selection.Start
                $end   = $state.Selection.End
                if ($state.Selection.Start -eq $state.CursorIndex) {
                        $start = $state.Selection.End
                        $end   = $state.Selection.Start
                }
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($start)

                $instance.GetType().
                    GetMethod('VisualSelectionCommon', $instanceFlags).
                    CreateDelegate([Action[Action]], $instance).
                    Invoke({ [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end) })

                $instance.GetType().
                    GetField('_visualSelectionCommandCount', $instanceFlags).
                    SetValue($instance, $state.Selection.Commands + 1)

            } elseif ($state.CursorIndex) {
                [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($state.CursorIndex)
            }
        }

        function RenderPrompt {
            [Microsoft.PowerShell.PSConsoleReadLine].
                GetMethod('Render', $instanceFlags).
                Invoke($instance, @())
        }

        # Draw the current search prompt
        function RenderPalette {
            # Setting this to 0 clears selection
            $instance.GetType().
                GetField('_visualSelectionCommandCount', $instanceFlags).
                SetValue($instance, 0)

            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            $promptBuffer.Clear()
            $currentMatch = GetCurrentMatch
            if ($currentMatch) {
                $null = $promptBuffer.AppendFormat('{0} - {1}', $currentMatch.Name, $currentMatch.Description)
            }
            $null = $promptBuffer.Append("`n").
                Append('CommandSearch: ').
                Append($buffer)

            RenderPrompt
        }

        function UpdateMatches([string] $searchTerms) {
            if ($searchTerms.Length) {
                # $matchList = Get-PSReadlineKeyHandler | Where-Object 'Function' -Like "*$searchTerms*"
                $matchList = Get-PSWritelineKeyHandler -Name "*$searchTerms*"
            } else {
                $matchList = $null
            }
            $currentMatchIndex = 0
        }

        function GetCurrentMatch {
            if (-not $matchList) { return }

            if ($matchList.Count -gt 1) {
                return $matchList[$currentMatchIndex]
            }
            return $matchList
        }

        # Increment match index (for tab handling)
        function MoveNext {
            if ($currentMatchIndex + 1 -eq $matchList.Count) {
                $currentMatchIndex = 0
                return
            }
            $currentMatchIndex++
        }

        # Decrement match index (for shift tab handling)
        function MovePrevious {
            if ($currentMatchIndex -eq 0) {
                $currentMatchIndex = $matchList.Count - 1
                return
            }
            $currentMatchIndex--
        }
        function GetHandlerAction {
            param(
                [PSTypeName('PSWriteline.Handler')] $Handler
            )
            if ($Handler.Action) {
                return $Handler.Action
            }

            $realHandler = $dispatchTable.
                Values.
                Where({ $_.BriefDescription -eq $Handler.Name }, 'First')

            if (-not $realHandler) {
                $realHandler = $chordDispatchTable.
                    Values.
                    Values.
                    Where({ $_.BriefDescription -eq $Handler.Name }, 'First')
            }

            if ($realHandler.ScriptBlock) {
                return $realHandler.ScriptBlock
            }

            return [Microsoft.PowerShell.PSConsoleReadLine]::($Handler.Name)
        }

        # Set defaults/constants and current state.
        $staticFlags        = [System.Reflection.BindingFlags]'Static, NonPublic'
        $instanceFlags      = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $instance           = [Microsoft.PowerShell.PSConsoleReadLine].GetField('_singleton', $staticFlags).GetValue($null)
        $promptBuffer       = [Microsoft.PowerShell.PSConsoleReadLine].GetField('_buffer', $instanceFlags).GetValue($instance)
        $dispatchTable      = [Microsoft.PowerShell.PSConsoleReadLine].GetField('_dispatchTable', $instanceFlags).GetValue($instance)
        $chordDispatchTable = [Microsoft.PowerShell.PSConsoleReadLine].GetField('_chordDispatchTable', $instanceFlags).GetValue($instance)
        $buffer             = [System.Text.StringBuilder]::new()
        $matchList          = $null
        $currentMatchIndex  = 0
        $bufferState        = ExportState

        # Main input loop.
        while ($true) {
            RenderPalette
            $key = [console]::ReadKey()
            $null = . {
                if ($key.Key -eq 'Backspace') {
                    if ($buffer.Length) {
                        $buffer.Remove($buffer.Length - 1, 1)
                        . UpdateMatches $buffer
                    }
                } elseif ($key.Key -eq 'Escape') {
                    ImportState $bufferState
                    RenderPrompt
                    break
                } elseif ($key.Key -eq 'Tab') {
                    if ($key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) {
                        . MovePrevious
                    } else {
                        . MoveNext
                    }
                } elseif ($key.Key -eq 'Enter') {
                    ImportState $bufferState
                    RenderPrompt

                    if ($currentMatch = GetCurrentMatch) {
                        if ($handlerAction = GetHandlerAction -Handler $currentMatch) {
                            $handlerAction.Invoke()
                        }
                    }

                    break
                } else {
                    if (-not $key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
                        $buffer.Append($key.KeyChar)
                        . UpdateMatches $buffer
                    }
                }
            }
        }
    }
}
