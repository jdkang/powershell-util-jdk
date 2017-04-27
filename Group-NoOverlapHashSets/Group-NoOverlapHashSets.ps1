function Group-NoOverlapHashSets {
[CmdletBinding(DefaultParameterSetName='FromInputObject')]
param(
    # Object which is either a HashSet<System.Object> or contains a property HashSet<System.Object>
    [Parameter(ValueFromPipeline=$true)]
    [object[]]
    $InputObject,
    # Specify the property which is as HashSet<System.Object>
    [Parameter(ParameterSetName='FromProperty',Mandatory=$true)]
    [System.Object]
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
        write-verbose "Matching Set $($wrapperObj.HashSet)"
        # Add to any existing Set Groups that don't overlap
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
                SuperSet = new-object 'System.Collections.Generic.HashSet[System.Object]'($wrapperObj.HashSet)
                Sets = @(,$wrapperObj.HashSet)
                Objects = @()
            }
            if($wrapperObj.Object -ne $null) {
                $newSetGroup.Objects += @(,$wrapperObj.Object)
            }
            $newSetGroup | Add-Member -MemberType ScriptProperty -Name "Count" -Value { $this.SuperSet.Count }
            $setGroups += $newSetGroup
        }
        # Sort so we're checking the largest SuperSets for a match first
        # Without check PS will unbox the array
        if($setGroups.count -gt 1) {
            $setGroups = $setGroups | Sort-Object -Property Count -Descending
        }
    }
    return $setGroups
}}