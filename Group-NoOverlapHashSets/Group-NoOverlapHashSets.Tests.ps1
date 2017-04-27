$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"
<#
###################################################
# Summary
###################################################
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
    
    
GROUPING PREFERENCE
-------------------
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
#>
Describe "Group-NoOverlapHashSets" {
    Context "HashSet Objects" {
        # Arrange
        $set1 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set2 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set3 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set4 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set5 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set6 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set7 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set1.add('a') | out-null; $set1.add('b') | out-null; $set1.add('c') | out-null
        $set2.add('d') | out-null; $set2.add('e') | out-null; $set2.add('f') | out-null
        $set3.add('b') | out-null; $set3.add('e') | out-null; $set3.add('f') | out-null
        $set4.add('f') | out-null; $set4.add('g') | out-null; $set4.add('h') | out-null
        $set5.add('x') | out-null; $set5.add('y') | out-null; $set5.add('z') | out-null
        $set6.add('q') | out-null; $set6.add('r') | out-null; $set6.add('s') | out-null
        $set7.add('a') | out-null; $set7.add('b') | out-null; $set7.add('q') | out-null
        $set1llSets = @($set1,$set2,$set3,$set4,$set5,$set6,$set7)
        # Expected SuperSets
        $expectedSuperSetA += new-object 'System.Collections.Generic.HashSet[System.Object]'
        $expectedSuperSetB += new-object 'System.Collections.Generic.HashSet[System.Object]'
        $expectedSuperSetC += new-object 'System.Collections.Generic.HashSet[System.Object]'
        $expectedSuperSetA.UnionWith($set1)
        $expectedSuperSetA.UnionWith($set2)
        $expectedSuperSetA.UnionWith($set5)
        $expectedSuperSetA.UnionWith($set6)
        $expectedSuperSetB.UnionWith($set4)
        $expectedSuperSetB.UnionWith($set7)
        $expectedSuperSetC.UnionWith($set3)
        
        # Act
        $result = Group-NoOverlapHashSets -InputObject $set1llSets
        
        # Assert
        It "Should Return Valid Counts" {
            $noCountObj = $result | where-object { ($_.Count -eq $null) -or ($_.Count -le 0) }
            $noCountObj | Should Be $null
        }
        It "Should Return Expected Number of Results" {
            $result.Count | Should Be 3
        }
        It "Should Match Expected SuperSets" {
            $result[0].SuperSet.SetEquals($expectedSuperSetA) | Should Be $true
            $result[1].SuperSet.SetEquals($expectedSuperSetB) | Should Be $true
            $result[2].SuperSet.SetEquals($expectedSuperSetC) | Should Be $true
        }
        It "Should Match Expected Sets" {
            $result[0].Sets[0].SetEquals($set1)
            $result[0].Sets[1].SetEquals($set2)
            $result[0].Sets[2].SetEquals($set5)
            $result[0].Sets[3].SetEquals($set6)
            $result[1].Sets[0].SetEquals($set4)
            $result[1].Sets[1].SetEquals($set7)
            $result[2].Sets[0].SetEquals($set3)
        }
    }
    Context "HashSet as Property" {
        # Arrange
        $set1 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set2 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set3 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set4 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set5 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set6 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set7 = new-object 'System.Collections.Generic.HashSet[System.Object]'
        $set1.add('a') | out-null; $set1.add('b') | out-null; $set1.add('c') | out-null
        $set2.add('d') | out-null; $set2.add('e') | out-null; $set2.add('f') | out-null
        $set3.add('b') | out-null; $set3.add('e') | out-null; $set3.add('f') | out-null
        $set4.add('f') | out-null; $set4.add('g') | out-null; $set4.add('h') | out-null
        $set5.add('x') | out-null; $set5.add('y') | out-null; $set5.add('z') | out-null
        $set6.add('q') | out-null; $set6.add('r') | out-null; $set6.add('s') | out-null
        $set7.add('a') | out-null; $set7.add('b') | out-null; $set7.add('q') | out-null
        $set1llSetsAsProperty = @()
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's1'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set1) }
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's2'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set2) }
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's3'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set3) }
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's4'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set4) }
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's5'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set5) }
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's6'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set6) }
        $set1llSetsAsProperty += [pscustomobject]@{ Name = 's7'; Letters = new-object 'System.Collections.Generic.HashSet[System.Object]'($set7) }
        # Expected SuperSets
        $expectedSuperSetA += new-object 'System.Collections.Generic.HashSet[System.Object]'
        $expectedSuperSetB += new-object 'System.Collections.Generic.HashSet[System.Object]'
        $expectedSuperSetC += new-object 'System.Collections.Generic.HashSet[System.Object]'
        $expectedSuperSetA.UnionWith($set1)
        $expectedSuperSetA.UnionWith($set2)
        $expectedSuperSetA.UnionWith($set5)
        $expectedSuperSetA.UnionWith($set6)
        $expectedSuperSetB.UnionWith($set4)
        $expectedSuperSetB.UnionWith($set7)
        $expectedSuperSetC.UnionWith($set3)
        
        # Act
        $result = Group-NoOverlapHashSets -InputObject $set1llSetsAsProperty -HashSetProperty 'Letters'
        
        # Assert
        It "Should Return Valid Counts" {
            $noCountObj = $result | where-object { ($_.Count -eq $null) -or ($_.Count -le 0) }
            $noCountObj | Should Be $null
        }
        It "Should Return Expected Number of Results" {
            $result.Count | Should Be 3
        }
        It "Should Match Expected SuperSets" {
            $result[0].SuperSet.SetEquals($expectedSuperSetA) | Should Be $true
            $result[1].SuperSet.SetEquals($expectedSuperSetB) | Should Be $true
            $result[2].SuperSet.SetEquals($expectedSuperSetC) | Should Be $true
        }
        It "Should Match Expected Sets" {
            $result[0].Sets[0].SetEquals($set1)
            $result[0].Sets[1].SetEquals($set2)
            $result[0].Sets[2].SetEquals($set5)
            $result[0].Sets[3].SetEquals($set6)
            $result[1].Sets[0].SetEquals($set4)
            $result[1].Sets[1].SetEquals($set7)
            $result[2].Sets[0].SetEquals($set3)
        }
        It "Should Return Expected Objects as Properties" {
            $result[0].Objects[0].Name | Should Be "s1"
            $result[0].Objects[0].Letters.SetEquals($set1) | Should Be $true
            $result[0].Objects[1].Name | Should Be "s2"
            $result[0].Objects[1].Letters.SetEquals($set2) | Should Be $true
            $result[0].Objects[2].Name | Should Be "s5"
            $result[0].Objects[2].Letters.SetEquals($set5) | Should Be $true
            $result[0].Objects[3].Name | Should Be "s6"
            $result[0].Objects[3].Letters.SetEquals($set6) | Should Be $true
            $result[1].Objects[0].Name | Should Be "s4"
            $result[1].Objects[0].Letters.SetEquals($set4) | Should Be $true
            $result[1].Objects[1].Name | Should Be "s7"
            $result[1].Objects[1].Letters.SetEquals($set7) | Should Be $true
            $result[2].Objects[0].Name | Should Be "s3"
            $result[2].Objects[0].Letters.SetEquals($set3) | Should Be $true
        }
    }
    Context "Grouping Preference" {
        
    }
}
