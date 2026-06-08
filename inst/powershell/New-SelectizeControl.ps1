# Inline searchable WPF selection control adapted from Show-SelectizeDialog.ps1.
# It is embedded in the main WinShiny window and never creates a second Window.

function Get-WinShinySelectizeTheme {
    param([bool] $DarkMode)

    if ($DarkMode) {
        return [pscustomobject] @{
            Surface          = '#2B2B2B'
            SurfaceAlternate = '#323232'
            Border           = '#4A4A4A'
            BorderStrong     = '#707070'
            Text             = '#F5F5F5'
            MutedText        = '#B5B5B5'
            Accent           = '#60CDFF'
            ChipBackground   = '#334A5E'
            ChipBorder       = '#5BA6D6'
            ChipText         = '#F5F5F5'
            Hover            = '#3A3A3A'
            Selection        = '#3D566A'
            SelectionText    = '#FFFFFF'
        }
    }

    [pscustomobject] @{
        Surface          = '#FFFFFF'
        SurfaceAlternate = '#F8F8F8'
        Border           = '#D0D0D0'
        BorderStrong     = '#A0A0A0'
        Text             = '#1F1F1F'
        MutedText        = '#707070'
        Accent           = '#0067C0'
        ChipBackground   = '#E4F0FA'
        ChipBorder       = '#8AB8DF'
        ChipText         = '#1F1F1F'
        Hover            = '#EEEEEE'
        Selection        = '#D6E9F8'
        SelectionText    = '#1F1F1F'
    }
}

function ConvertTo-WinShinySelectizeBrush {
    param([Parameter(Mandatory)][string] $Value)
    [Windows.Media.BrushConverter]::new().ConvertFromString($Value)
}

function New-WinShinySelectizeItemStyle {
    param([Parameter(Mandatory)][object] $Theme)

    $xaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="{x:Type ListBoxItem}">
  <Setter Property="Padding" Value="10,7"/>
  <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
  <Setter Property="Foreground" Value="$($Theme.Text)"/>
  <Setter Property="Background" Value="Transparent"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="{x:Type ListBoxItem}">
        <Border x:Name="ItemBorder"
                Background="{TemplateBinding Background}"
                Padding="{TemplateBinding Padding}">
          <ContentPresenter VerticalAlignment="Center"
                            TextElement.Foreground="{TemplateBinding Foreground}"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="ItemBorder" Property="Background" Value="$($Theme.Hover)"/>
          </Trigger>
          <Trigger Property="IsSelected" Value="True">
            <Setter TargetName="ItemBorder" Property="Background" Value="$($Theme.Selection)"/>
            <Setter Property="Foreground" Value="$($Theme.SelectionText)"/>
          </Trigger>
          <Trigger Property="IsEnabled" Value="False">
            <Setter Property="Opacity" Value="0.55"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@

    [Windows.Markup.XamlReader]::Parse($xaml)
}

function Get-WinShinySelectizeValues {
    param([Parameter(Mandatory)][object] $Control)

    $state = $Control.Tag
    if ($null -eq $state -or [string] $Control.Uid -ne 'winshiny-selectize-inline') {
        return @()
    }

    @($state.SelectedItems | ForEach-Object { [string] $_.Value })
}

function Set-WinShinySelectizeTheme {
    param(
        [Parameter(Mandatory)][object] $Control,
        [bool] $DarkMode
    )

    $state = $Control.Tag
    if ($null -eq $state -or [string] $Control.Uid -ne 'winshiny-selectize-inline') {
        return
    }

    $theme = Get-WinShinySelectizeTheme -DarkMode $DarkMode
    $state.Theme = $theme

    $Control.Background = [Windows.Media.Brushes]::Transparent
    $state.InputBorder.Background = ConvertTo-WinShinySelectizeBrush $theme.Surface
    $state.InputBorder.BorderBrush = ConvertTo-WinShinySelectizeBrush $theme.BorderStrong
    $state.SearchBox.Background = [Windows.Media.Brushes]::Transparent
    $state.SearchBox.Foreground = ConvertTo-WinShinySelectizeBrush $theme.Text
    $state.SearchBox.CaretBrush = ConvertTo-WinShinySelectizeBrush $theme.Text
    $state.SearchPlaceholder.Foreground = ConvertTo-WinShinySelectizeBrush $theme.MutedText
    $state.ChoicesBorder.Background = ConvertTo-WinShinySelectizeBrush $theme.Surface
    $state.ChoicesBorder.BorderBrush = ConvertTo-WinShinySelectizeBrush $theme.Border
    $state.ChoicesList.Background = ConvertTo-WinShinySelectizeBrush $theme.Surface
    $state.ChoicesList.Foreground = ConvertTo-WinShinySelectizeBrush $theme.Text
    $state.ChoicesList.BorderBrush = ConvertTo-WinShinySelectizeBrush $theme.Border
    $state.ChoicesList.ItemContainerStyle = New-WinShinySelectizeItemStyle $theme

    if ($null -ne $state.RefreshInput) {
        & $state.RefreshInput $state
    }
}

function Set-WinShinySelectizeSelectedValues {
    param(
        [Parameter(Mandatory)][object] $Control,
        [AllowEmptyCollection()][object[]] $Values = @()
    )

    $state = $Control.Tag
    if ($null -eq $state -or [string] $Control.Uid -ne 'winshiny-selectize-inline') {
        return
    }

    $oldSuppress = $state.SuppressEvents
    $state.SuppressEvents = $true

    try {
        $state.SelectedItems.Clear()

        foreach ($value in @($Values)) {
            $match = @(
                $state.Items |
                    Where-Object { [string] $_.Value -ceq [string] $value }
            ) | Select-Object -First 1

            if ($null -ne $match) {
                [void] $state.SelectedItems.Add($match)
                if (-not $state.Multiple) {
                    break
                }
            }
        }

        $state.SearchBox.Clear()
        & $state.RefreshInput $state
        & $state.RefreshChoices $state
    }
    finally {
        $state.SuppressEvents = $oldSuppress
    }
}

function Set-WinShinySelectizeItems {
    param(
        [Parameter(Mandatory)][object] $Control,
        [AllowEmptyCollection()][object[]] $Items = @(),
        [string] $DisplayProperty,
        [string] $ValueProperty
    )

    $state = $Control.Tag
    if ($null -eq $state -or [string] $Control.Uid -ne 'winshiny-selectize-inline') {
        return
    }

    $selectedValues = @(Get-WinShinySelectizeValues $Control)
    $oldSuppress = $state.SuppressEvents
    $state.SuppressEvents = $true

    try {
        $state.Items.Clear()
        $index = 0

        foreach ($item in @($Items)) {
            if ($DisplayProperty) {
                $displayPropertyValue = $item.PSObject.Properties[$DisplayProperty]
                if ($null -eq $displayPropertyValue) {
                    throw "An item does not contain display property '$DisplayProperty'."
                }
                $display = [string] $displayPropertyValue.Value
            }
            else {
                $display = [string] $item
            }

            if ($ValueProperty) {
                $valuePropertyValue = $item.PSObject.Properties[$ValueProperty]
                if ($null -eq $valuePropertyValue) {
                    throw "An item does not contain value property '$ValueProperty'."
                }
                $value = $valuePropertyValue.Value
            }
            else {
                $value = $item
            }

            [void] $state.Items.Add([pscustomobject] @{
                Index    = $index
                Display  = $display
                Value    = $value
                Original = $item
            })
            $index++
        }

        Set-WinShinySelectizeSelectedValues -Control $Control -Values $selectedValues
    }
    finally {
        $state.SuppressEvents = $oldSuppress
    }
}

function New-WinShinySelectizeControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Items,

        [AllowEmptyCollection()]
        [object[]] $SelectedValues = @(),

        [bool] $Multiple = $false,

        [string] $Prompt = 'Search and select an item...',

        [Parameter(Mandatory)]
        [string] $InputId,

        [bool] $DarkMode = $false,

        [string] $DisplayProperty,

        [string] $ValueProperty,

        [ValidateRange(80, 1000)]
        [int] $ChoicesHeight = 220
    )

    $root = [Windows.Controls.StackPanel]::new()
    $root.Uid = 'winshiny-selectize-inline'
    $root.HorizontalAlignment = 'Stretch'
    $root.Focusable = $true

    $inputBorder = [Windows.Controls.Border]::new()
    $inputBorder.MinHeight = 38
    $inputBorder.MaxHeight = if ($Multiple) { 130 } else { 78 }
    $inputBorder.BorderThickness = [Windows.Thickness]::new(1)
    $inputBorder.CornerRadius = [Windows.CornerRadius]::new(5)
    $inputBorder.Cursor = 'IBeam'

    $inputScroller = [Windows.Controls.ScrollViewer]::new()
    $inputScroller.HorizontalScrollBarVisibility = 'Disabled'
    $inputScroller.VerticalScrollBarVisibility = 'Auto'

    $inputPanel = [Windows.Controls.WrapPanel]::new()
    $inputPanel.Margin = [Windows.Thickness]::new(6, 5, 6, 2)

    $searchContainer = [Windows.Controls.Grid]::new()
    $searchContainer.MinWidth = 210
    $searchContainer.Margin = [Windows.Thickness]::new(2, 0, 2, 3)

    $searchBox = [Windows.Controls.TextBox]::new()
    $searchBox.MinWidth = 200
    $searchBox.Padding = [Windows.Thickness]::new(4, 4, 4, 4)
    $searchBox.BorderThickness = [Windows.Thickness]::new(0)
    $searchBox.FontSize = 14

    $searchPlaceholder = [Windows.Controls.TextBlock]::new()
    $searchPlaceholder.Margin = [Windows.Thickness]::new(7, 0, 0, 0)
    $searchPlaceholder.VerticalAlignment = 'Center'
    $searchPlaceholder.IsHitTestVisible = $false
    $searchPlaceholder.Text = $Prompt

    [void] $searchContainer.Children.Add($searchBox)
    [void] $searchContainer.Children.Add($searchPlaceholder)
    [void] $inputPanel.Children.Add($searchContainer)
    $inputScroller.Content = $inputPanel
    $inputBorder.Child = $inputScroller

    $choicesBorder = [Windows.Controls.Border]::new()
    $choicesBorder.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    $choicesBorder.BorderThickness = [Windows.Thickness]::new(1)
    $choicesBorder.CornerRadius = [Windows.CornerRadius]::new(5)
    $choicesBorder.MaxHeight = $ChoicesHeight
    $choicesBorder.Visibility = 'Collapsed'

    $choicesList = [Windows.Controls.ListBox]::new()
    $choicesList.BorderThickness = [Windows.Thickness]::new(0)
    $choicesList.DisplayMemberPath = 'Display'
    $choicesList.SelectionMode = 'Single'
    $choicesList.HorizontalContentAlignment = 'Stretch'
    [Windows.Controls.ScrollViewer]::SetHorizontalScrollBarVisibility(
        $choicesList,
        [Windows.Controls.ScrollBarVisibility]::Disabled
    )
    $choicesBorder.Child = $choicesList

    [void] $root.Children.Add($inputBorder)
    [void] $root.Children.Add($choicesBorder)

    $state = [pscustomobject] @{
        Root              = $root
        InputBorder       = $inputBorder
        InputPanel        = $inputPanel
        SearchContainer   = $searchContainer
        SearchBox         = $searchBox
        SearchPlaceholder = $searchPlaceholder
        ChoicesBorder     = $choicesBorder
        ChoicesList       = $choicesList
        Items             = [System.Collections.Generic.List[object]]::new()
        SelectedItems     = [System.Collections.Generic.List[object]]::new()
        Multiple          = $Multiple
        Prompt            = $Prompt
        InputId           = $InputId
        Theme             = Get-WinShinySelectizeTheme -DarkMode $DarkMode
        SuppressEvents    = $true

        RefreshChoices = $null
        RefreshInput   = $null
        NotifyChange   = $null
        AddCurrentItem = $null
        RemoveItem     = $null
        OpenChoices    = $null
        CloseChoices   = $null
    }

    $refreshChoices = {
        param([Parameter(Mandatory)][object] $State)

        $query = $State.SearchBox.Text.Trim()
        $selectedIndexes = @($State.SelectedItems | ForEach-Object { $_.Index })

        $filteredItems = @(
            $State.Items |
                Where-Object {
                    $notSelected = $_.Index -notin $selectedIndexes
                    $matchesFilter =
                        [string]::IsNullOrWhiteSpace($query) -or
                        $_.Display.IndexOf(
                            $query,
                            [StringComparison]::CurrentCultureIgnoreCase
                        ) -ge 0

                    $notSelected -and $matchesFilter
                }
        )

        $State.ChoicesList.ItemsSource = $null
        $State.ChoicesList.ItemsSource = $filteredItems
        $State.ChoicesList.SelectedIndex = -1
    }

    $notifyChange = {
        param([Parameter(Mandatory)][object] $State)

        if ($State.SuppressEvents) {
            return
        }

        $values = [string[]] @(
            $State.SelectedItems |
                ForEach-Object { [string] $_.Value }
        )

        if ($State.Multiple) {
            Send-Event $State.InputId $values
        }
        else {
            $value = if ($values.Count -gt 0) { $values[0] } else { '' }
            Send-Event $State.InputId $value
        }

        Flush-PendingEvents
    }

    $removeItem = {
        param(
            [Parameter(Mandatory)][object] $State,
            [Parameter(Mandatory)][object] $Entry
        )

        [void] $State.SelectedItems.Remove($Entry)
        & $State.RefreshInput $State
        & $State.RefreshChoices $State
        & $State.NotifyChange $State
        [void] $State.SearchBox.Focus()
    }

    $refreshInput = {
        param([Parameter(Mandatory)][object] $State)

        $searchHadFocus = $State.SearchBox.IsKeyboardFocused
        $State.InputPanel.Children.Clear()

        foreach ($entry in $State.SelectedItems) {
            $chip = [Windows.Controls.Border]::new()
            $chip.Background = ConvertTo-WinShinySelectizeBrush $State.Theme.ChipBackground
            $chip.BorderBrush = ConvertTo-WinShinySelectizeBrush $State.Theme.ChipBorder
            $chip.BorderThickness = [Windows.Thickness]::new(1)
            $chip.CornerRadius = [Windows.CornerRadius]::new(12)
            $chip.Padding = [Windows.Thickness]::new(9, 3, 4, 3)
            $chip.Margin = [Windows.Thickness]::new(0, 0, 6, 4)
            $chip.Focusable = $true
            $chip.ToolTip = 'Press Backspace or Delete to remove'

            $chipContent = [Windows.Controls.StackPanel]::new()
            $chipContent.Orientation = 'Horizontal'
            $chipContent.Background = [Windows.Media.Brushes]::Transparent

            $chipText = [Windows.Controls.TextBlock]::new()
            $chipText.Text = $entry.Display
            $chipText.VerticalAlignment = 'Center'
            $chipText.Margin = [Windows.Thickness]::new(1, 0, 2, 0)
            $chipText.Foreground = ConvertTo-WinShinySelectizeBrush $State.Theme.ChipText

            $removeButton = [Windows.Controls.Button]::new()
            $removeButton.Content = [char] 0x00D7
            $removeButton.ToolTip = "Remove $($entry.Display)"
            $removeButton.MinWidth = 21
            $removeButton.MinHeight = 20
            $removeButton.Padding = [Windows.Thickness]::new(2, 0, 2, 0)
            $removeButton.Margin = [Windows.Thickness]::new(5, 0, 0, 0)
            $removeButton.BorderThickness = [Windows.Thickness]::new(0)
            $removeButton.Background = [Windows.Media.Brushes]::Transparent
            $removeButton.Foreground = ConvertTo-WinShinySelectizeBrush $State.Theme.ChipText
            $removeButton.Cursor = 'Hand'
            $removeButton.Focusable = $false

            $chipContext = [pscustomobject] @{ State = $State; Entry = $entry }
            $chip.Tag = $chipContext
            $removeButton.Tag = $chipContext

            $chip.Add_MouseLeftButtonDown({
                param($sender, $eventArgs)

                $element = $eventArgs.OriginalSource
                while ($null -ne $element -and $element -ne $sender) {
                    if ($element -is [Windows.Controls.Button]) {
                        return
                    }
                    try {
                        $element = [Windows.Media.VisualTreeHelper]::GetParent($element)
                    }
                    catch {
                        $element = $null
                    }
                }

                [void] $sender.Focus()
                $eventArgs.Handled = $true
            })

            $chip.Add_GotKeyboardFocus({
                param($sender, $eventArgs)
                $context = $sender.Tag
                if ($null -ne $context) {
                    $sender.BorderBrush = ConvertTo-WinShinySelectizeBrush $context.State.Theme.Accent
                    $sender.BorderThickness = [Windows.Thickness]::new(2)
                }
            })

            $chip.Add_LostKeyboardFocus({
                param($sender, $eventArgs)
                $context = $sender.Tag
                if ($null -ne $context) {
                    $sender.BorderBrush = ConvertTo-WinShinySelectizeBrush $context.State.Theme.ChipBorder
                    $sender.BorderThickness = [Windows.Thickness]::new(1)
                }
            })

            $chip.Add_PreviewKeyDown({
                param($sender, $eventArgs)
                if ($eventArgs.Key -notin @('Back', 'Delete')) {
                    return
                }

                $context = $sender.Tag
                if ($null -ne $context) {
                    $eventArgs.Handled = $true
                    & $context.State.RemoveItem $context.State $context.Entry
                }
            })

            $removeButton.Add_Click({
                param($sender, $eventArgs)
                $context = $sender.Tag
                if ($null -ne $context) {
                    & $context.State.RemoveItem $context.State $context.Entry
                }
            })

            [void] $chipContent.Children.Add($chipText)
            [void] $chipContent.Children.Add($removeButton)
            $chip.Child = $chipContent
            [void] $State.InputPanel.Children.Add($chip)
        }

        [void] $State.InputPanel.Children.Add($State.SearchContainer)

        $State.SearchPlaceholder.Visibility = if (
            $State.SearchBox.Text.Length -gt 0 -or
            $State.SelectedItems.Count -gt 0
        ) {
            'Collapsed'
        }
        else {
            'Visible'
        }

        if ($searchHadFocus) {
            [void] $State.SearchBox.Focus()
        }
    }

    $openChoices = {
        param([Parameter(Mandatory)][object] $State)
        & $State.RefreshChoices $State
        $State.ChoicesBorder.Visibility = 'Visible'
    }

    $closeChoices = {
        param([Parameter(Mandatory)][object] $State)
        $State.ChoicesList.SelectedIndex = -1
        $State.ChoicesBorder.Visibility = 'Collapsed'
    }

    $addCurrentItem = {
        param([Parameter(Mandatory)][object] $State)

        $entry = $State.ChoicesList.SelectedItem
        if ($null -eq $entry -and $State.ChoicesList.Items.Count -gt 0) {
            $entry = $State.ChoicesList.Items[0]
        }
        if ($null -eq $entry) {
            return
        }

        if ($State.Multiple) {
            if (-not ($State.SelectedItems | Where-Object { $_.Index -eq $entry.Index })) {
                [void] $State.SelectedItems.Add($entry)
            }
        }
        else {
            $State.SelectedItems.Clear()
            [void] $State.SelectedItems.Add($entry)
        }

        $State.SearchBox.Clear()
        & $State.RefreshInput $State
        & $State.RefreshChoices $State
        & $State.NotifyChange $State

        if ($State.Multiple) {
            & $State.OpenChoices $State
            [void] $State.SearchBox.Focus()
        }
        else {
            & $State.CloseChoices $State
            [void] $State.Root.Focus()
        }
    }

    $state.RefreshChoices = $refreshChoices
    $state.RefreshInput = $refreshInput
    $state.NotifyChange = $notifyChange
    $state.AddCurrentItem = $addCurrentItem
    $state.RemoveItem = $removeItem
    $state.OpenChoices = $openChoices
    $state.CloseChoices = $closeChoices

    $root.Tag = $state
    $inputBorder.Tag = $state
    $searchBox.Tag = $state
    $choicesList.Tag = $state

    $inputBorder.Add_MouseLeftButtonDown({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -ne $controlState) {
            & $controlState.OpenChoices $controlState
            [void] $controlState.SearchBox.Focus()
        }
    })

    $searchBox.Add_GotKeyboardFocus({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -ne $controlState) {
            $controlState.InputBorder.BorderBrush = ConvertTo-WinShinySelectizeBrush $controlState.Theme.Accent
            $controlState.InputBorder.BorderThickness = [Windows.Thickness]::new(2)
            & $controlState.OpenChoices $controlState
        }
    })

    $searchBox.Add_LostKeyboardFocus({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -ne $controlState) {
            $controlState.InputBorder.BorderBrush = ConvertTo-WinShinySelectizeBrush $controlState.Theme.BorderStrong
            $controlState.InputBorder.BorderThickness = [Windows.Thickness]::new(1)
        }
    })

    $searchBox.Add_TextChanged({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -eq $controlState) {
            return
        }

        $controlState.SearchPlaceholder.Visibility = if (
            $sender.Text.Length -gt 0 -or
            $controlState.SelectedItems.Count -gt 0
        ) {
            'Collapsed'
        }
        else {
            'Visible'
        }

        & $controlState.RefreshChoices $controlState
        if ($sender.IsKeyboardFocused) {
            $controlState.ChoicesBorder.Visibility = 'Visible'
        }
    })

    $searchBox.Add_PreviewKeyDown({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -eq $controlState) {
            return
        }

        switch ($eventArgs.Key) {
            'Enter' {
                & $controlState.AddCurrentItem $controlState
                $eventArgs.Handled = $true
            }
            'Down' {
                & $controlState.OpenChoices $controlState
                if ($controlState.ChoicesList.Items.Count -gt 0) {
                    [void] $controlState.ChoicesList.Focus()
                    $controlState.ChoicesList.SelectedIndex = 0
                }
                $eventArgs.Handled = $true
            }
            'Back' {
                if ($sender.Text.Length -eq 0 -and $controlState.SelectedItems.Count -gt 0) {
                    $lastEntry = $controlState.SelectedItems[$controlState.SelectedItems.Count - 1]
                    & $controlState.RemoveItem $controlState $lastEntry
                    $eventArgs.Handled = $true
                }
            }
            'Delete' {
                if ($sender.Text.Length -eq 0 -and $controlState.SelectedItems.Count -gt 0) {
                    $lastEntry = $controlState.SelectedItems[$controlState.SelectedItems.Count - 1]
                    & $controlState.RemoveItem $controlState $lastEntry
                    $eventArgs.Handled = $true
                }
            }
            'Left' {
                if ($sender.Text.Length -eq 0 -and $controlState.InputPanel.Children.Count -gt 1) {
                    $lastChip = $controlState.InputPanel.Children[$controlState.InputPanel.Children.Count - 2]
                    if ($lastChip.Focusable) {
                        [void] $lastChip.Focus()
                        $eventArgs.Handled = $true
                    }
                }
            }
            'Escape' {
                & $controlState.CloseChoices $controlState
                $eventArgs.Handled = $true
            }
        }
    })

    $choicesList.Add_MouseLeftButtonUp({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -eq $controlState) {
            return
        }

        try {
            $container = [Windows.Controls.ItemsControl]::ContainerFromElement(
                $sender,
                [Windows.DependencyObject] $eventArgs.OriginalSource
            )
        }
        catch {
            $container = $null
        }

        if ($container -is [Windows.Controls.ListBoxItem]) {
            $sender.SelectedItem = $container.Content
            & $controlState.AddCurrentItem $controlState
            $eventArgs.Handled = $true
        }
    })

    $choicesList.Add_PreviewKeyDown({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -eq $controlState) {
            return
        }

        switch ($eventArgs.Key) {
            'Enter' {
                & $controlState.AddCurrentItem $controlState
                $eventArgs.Handled = $true
            }
            'Space' {
                & $controlState.AddCurrentItem $controlState
                $eventArgs.Handled = $true
            }
            'Escape' {
                & $controlState.CloseChoices $controlState
                [void] $controlState.SearchBox.Focus()
                $eventArgs.Handled = $true
            }
        }
    })

    $root.Add_LostKeyboardFocus({
        param($sender, $eventArgs)
        $controlState = $sender.Tag
        if ($null -eq $controlState) {
            return
        }

        $action = [Action] ({
            if (-not $controlState.Root.IsKeyboardFocusWithin) {
                & $controlState.CloseChoices $controlState
            }
        }.GetNewClosure())

        [void] $sender.Dispatcher.BeginInvoke(
            $action,
            [Windows.Threading.DispatcherPriority]::Input
        )
    })

    Set-WinShinySelectizeItems -Control $root -Items $Items -DisplayProperty $DisplayProperty -ValueProperty $ValueProperty

    Set-WinShinySelectizeSelectedValues -Control $root -Values $SelectedValues

    Set-WinShinySelectizeTheme -Control $root -DarkMode $DarkMode
    $state.SuppressEvents = $false

    $root
}
