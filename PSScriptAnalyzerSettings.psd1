@{
    Severity = @('Error', 'Warning')
    IncludeRules = @(
        'PSUseCompatibleSyntax',
        'PSAvoidAssignmentToAutomaticVariable',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingBrokenHashAlgorithms'
    )
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1')
        }
    }
}
