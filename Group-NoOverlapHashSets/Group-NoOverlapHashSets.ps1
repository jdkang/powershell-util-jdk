function Group-NoOverlapHashSets {
<#
    .SYNOPSIS
    Groups a set of HashSet<System.Object> based on NO overlapping values
    
    .DESCRIPTION
    Given an array of sets, this will the largest groupings of those sets which do not have any overlapping values.

    Given the sets:
        {a b c}
        {d e f}
        {b e f}
        {f g h}
        {x y z}
        {q r s}
        {a b q}

    We want to group them into the largest possible groups where NO elements overlap.
    Given the above, we would expect the result to be:
        { a b c d e f x y z q r s }
        { f g h a b q }
        { b e f }
        
    This was designed to help analyze a complex array of deployments with potentially overlapping target servers. The idea was to maximize concurrenct, non-overlapping deployments where possible.
    
    GROUPING PREFERENCE
    ---------=======---
    Note that it keeps the results "sorted" by SuperSet count at all times in order to maximize the chances of grouping into the largest SuperSet.
    
    However, there is the condition where two SuperSets have an equal count. In this case, we need a tie-breaker, so we expose an ordered, concat value "AllElements" as a secondary sort key.
    
    In order of preference: (1) Highest Count (2) First AllElement (sorted ascending)
    
    e.g.
        { a b c } \_ Group A
        { d e f } /
        { a b e } \_ Group B
        { c j k } /  
        { q r s } -  Set
    
    Group A*
        Count: 6
        AllElement: abcdef
    Group B
        Count: 6
        AllElement: abcejk
    
    Which would result in:
        { a b c d e f q r s }
        { a b e c j k }
    
    .INPUTS
    System.Collection.Generic.HashSet<System.Object>
    
    .OUTPUTS
    System.Management.Automation.PSCustomObject[]
    
    .EXAMPLE
    Group-NoOverlapHashSets -InputObject $sets
    
    Basic usage against an array of HashSet<System.Object>
    
    # Declaring HashSets in PS:
    $a = new-object 'System.Collections.Generic.HashSet[System.Object]'
    $a.add('cat'); $a.add('dog'); $a.add('parrot')
    $b = new-object 'System.Collections.Generic.HashSet[System.Object]'
    $b.add('dog'); $b.add('chtulu'); $b.add('snake')
    $c = new-object 'System.Collections.Generic.HashSet[System.Object]'
    $c.add('iguana'); $c.add('raptor'); $c.add('fish')
    $sets = @($a,$b,$c)
    # ...
    
    .EXAMPLE
    $sets | Group-NoOverlapHashSets
    
    .EXAMPLE
    Group-NoOverlapHashSets -Initalize $objWithSetProperty -HashSetProperty 'Animals'
    
    Supports grouping by a property which is a HashSet<System.Object> such as
    $obj1 = [pscustomobject]@{ owner = 'bob loblaw'; Animals = new-object 'System.Collections.Generic.HashSet[System.Object]' }
    $obj1.Animals.Add('tiger')
    $obj1.Animals.Add('goat')
    $obj1.Animals.Add('capybara')
    # ...
    
#>
[CmdletBinding(DefaultParameterSetName='FromInputObject')]
param(
    # Object which is either a HashSet<System.Object> or contains a property HashSet<System.Object>
    [Parameter(ValueFromPipeline=$true)]
    [object[]]
    $InputObject,
    # Specify the property which is as HashSet<System.Object>
    [Parameter(ParameterSetName='FromProperty',Mandatory=$true)]
    [string]
    $HashSetProperty,
    [switch]$DebugReturnWrapperObjs
)
BEGIN {
    $wrapperObjs = @()
    write-verbose "ParameterSetName: $($PsCmdlet.ParameterSetName)"
}
PROCESS {
    # --- Poor man's data structure ---
    write-verbose "Wrapping input objects"
    # Wrap InputObject
    foreach($obj in $InputObject) {
        $wrapperObj = [pscustomobject]@{
            Object = $null
            HashSet = $null
        }
        $hashSetObj = $null
        switch($PsCmdlet.ParameterSetName) {
            'FromInputObject' {
                write-verbose "Assuming hashset is object"
                $hashSetObj = $obj
            }
            'FromProperty' {
                write-verbose "Checking for property $($HashSetProperty)"
                foreach($prop in $obj.PsObject.Properties) {
                    if($prop.Name -eq $HashSetProperty) {
                        write-verbose "Property $($HashSetProperty) found"
                        $hashSetObj = $obj."$($HashSetProperty)"
                        break
                    }
                }
                if($hashSetObj -ne $null) {
                    $wrapperObj.Object = $obj
                }
            }
            default { throw "unknown propertyset condition" }
        }
        # Should figure out a way to support HashSet<T>
        if($hashSetObj -eq $null) {
            write-error "Object or object property is null"
        } elseif(!($hashSetObj -is [System.Collections.Generic.HashSet[System.Object]])) {
            write-error "Object or object property must be type HashSet<System.Object>"
        } else {
            $wrapperObj.HashSet = new-object 'System.Collections.Generic.HashSet[System.Object]'($hashSetObj)
            write-verbose "Adding wrapped object with set $($wrapperObj.HashSet)"
            $wrapperObjs += $wrapperObj
        }
    }
}
END {
    if($DebugReturnWrapperObjs) { return $wrapperObjs }
    write-verbose "Grouping wrapped objects"
    $setGroups = @()
    foreach($wrapperObj in $wrapperObjs) {
        # Add to any existing Set Groups that don't overlap
        write-verbose "Matching Set $($wrapperObj.HashSet)"
        $matchResult = $false
        if($setGroups.count -ne 0) {
            foreach($setGroup in $setGroups) {
                write-verbose "Checking SetGroup SuperSet $($setGroup.SuperSet)"
                if(!$setGroup.SuperSet.Overlaps($wrapperObj.HashSet)) {
                    $setGroup.Sets += @(,$wrapperObj.HashSet)
                    $setGroup.SuperSet.UnionWith($wrapperObj.HashSet)
                    if($wrapperObj.Object -ne $null) {
                        $setGroup.Objects += @(,$wrapperObj.Object)
                    }
                    write-verbose "Merging into SetGroup SuperSet: $($setGroup.SuperSet)"
                    $matchResult = $true
                    break
                }
            }
        }
        # Initalize a New SetGroup if necessary
        if(!$matchResult) {
            write-verbose "New SetGroup"
            $newSetGroup = [pscustomobject]@{
                PsTypeName = 'HashSetGroup'
                SuperSet = new-object 'System.Collections.Generic.HashSet[System.Object]'($wrapperObj.HashSet)
                Sets = @(,$wrapperObj.HashSet)
                Objects = @()
                GroupId = -1
            }
            if($wrapperObj.Object -ne $null) {
                $newSetGroup.Objects += @(,$wrapperObj.Object)
            }
            # Primary sort key
            $newSetGroup | Add-Member -MemberType ScriptProperty -Name "Count" -Value {
                $this.SuperSet.Count
            }
            # Secondary Sort Key
            $newSetGroup | Add-Member -MemberType ScriptProperty -Name 'AllElements' -Value {
                $x = $this.SuperSet -as [object[]]
                [array]::Sort($x)
                $x -join ''
            }
            $setGroups += $newSetGroup
        }
        # Sort so we're checking the largest SuperSets for a match first
        # Without check PS will unbox the array
        if($setGroups.count -gt 1) {
            $setGroups = $setGroups | Sort-Object -Property @{Expression = "Count"; Descending = $True}, @{Expression = "AllElements"; Descending = $False}
        }
    }
    # Stamp GroupIds based on final order
    $groupId = 0
    foreach($setGroup in $setGroups) {
        $groupId++
        $setGroup.GroupId = $groupId
    }
    # ret
    return $setGroups
}}