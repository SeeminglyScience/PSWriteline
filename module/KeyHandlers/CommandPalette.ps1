function CommandPalette {
    param(
        [System.Nullable[System.ConsoleKeyInfo]] $key,
        [object] $arg
    )
    end {
        $resultGetter = {
            param([string] $Query)
            end {
                return Get-PSWritelineKeyHandler -Name "*$Query*"
            }
        }
        $resultFormatter = {
            param([psobject] $Handler)
            end {
                return '{0} - {1}' -f $Handler.Name, $Handler.Description
            }
        }

        $result = InvokeStatusPrompt `
            -Prompt 'Command Search' `
            -ResultGetterCallback $resultGetter `
            -ResultFormatterCallback $resultFormatter

        if (-not $result) { return }

        $action = GetHandlerAction -Handler $result
        $action.Invoke()
    }
}
