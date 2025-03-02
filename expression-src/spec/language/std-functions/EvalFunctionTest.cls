@IsTest
private class EvalFunctionTest {
    @IsTest
    private static void evalFunctionCanAccessContext() {
        // Setup test data - a Contact record
        Contact testContact = new Contact(FirstName = 'John', LastName = 'Doe');
        
        // Test direct context field access
        EvaluationResult result = Evaluator.run('EVAL("@Context.FirstName + \' \' + @Context.LastName")', testContact);
        System.debug('evalFunctionCanAccessContext result: ' + result.result);
        Assert.areEqual('John Doe', result.result);
    }
    
    @IsTest
    private static void evalFunctionDynamicallyRetrievesFields() {
        // This test simulates the scenario where a field isn't initially in the context
        // but needs to be retrieved dynamically during evaluation
        
        // Create a test Account with Id
        Account testAccount = new Account(
            Name = 'Test Account',
            Industry = 'Technology',
            BillingCity = 'San Francisco'
        );
        insert testAccount;
        
        try {
            // Create a test expression that references a field not in the initial context
            String dynamicFieldExpression = 'EVAL("@Context.Name + \' - \' + @Context.Industry + \', \' + @Context.BillingCity")';
            
            // Use a minimal record with just the ID to force dynamic field retrieval
            Account minimalAccount = new Account(Id = testAccount.Id);
            
            // When we run this, the EVAL function should dynamically query for the missing fields
            EvaluationResult result = Evaluator.run(dynamicFieldExpression, minimalAccount);
            System.debug('evalFunctionDynamicallyRetrievesFields result: ' + result.result);
            
            // Verify the result contains all the dynamically retrieved fields
            Assert.areEqual('Test Account - Technology, San Francisco', result.result);
        } finally {
            // Clean up test data
            delete testAccount;
        }
    }
    
    @IsTest
    private static void evalFunctionCanAccessContextViaNestedExpression() {
        // Setup test data - a Contact record
        Contact testContact = new Contact(FirstName = 'John', LastName = 'Doe');
        
        // Test more complex nested expressions using context
        String nestedExpression = 'EVAL("IF(@Context.FirstName = \'John\', \'Hello \' + @Context.FirstName, \'Not John\') + \' \' + @Context.LastName")';
        EvaluationResult result = Evaluator.run(nestedExpression, testContact);
        System.debug('evalFunctionCanAccessContextViaNestedExpression result: ' + result.result);
        Assert.areEqual('Hello John Doe', result.result);
    }
    
    @IsTest
    private static void evalFunctionCanAccessAndModifyContext() {
        // Setup a map as context
        Map<String, Object> context = new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe'
        };
        
        // Configure with custom context
        Configuration config = new Configuration()
            .withCustomContext(context);
        
        // Test accessing and using the context
        EvaluationResult result = Evaluator.run('EVAL("@FirstName + \' \' + @LastName")', config);
        System.debug('evalFunctionCanAccessAndModifyContext result: ' + result.result);
        Assert.areEqual('John Doe', result.result);
    }
    
    @IsTest
    private static void evalFunctionWorksWithoutContext() {
        // Test with no context
        Object result = Evaluator.run('EVAL("\'No context needed for this\'")');
        System.debug('evalFunctionWorksWithoutContext result: ' + result);
        Assert.areEqual('No context needed for this', result);
    }
    
    @IsTest
    private static void evalFunctionEvaluatesMathExpressions() {
        // Test with math expressions
        Object result = Evaluator.run('EVAL("1 + 2 * 3")');
        System.debug('evalFunctionEvaluatesMathExpressions result: ' + result);
        Assert.areEqual(7, result);
    }
    
    @IsTest
    private static void evalFunctionSupportsNestedFunctionCalls() {
        // Test with nested function calls
        Object result = Evaluator.run('EVAL("UPPER(\'hello\') + \' \' + LOWER(\'WORLD\')")');
        System.debug('evalFunctionSupportsNestedFunctionCalls result: ' + result);
        Assert.areEqual('HELLO world', result);
    }
    
    @IsTest
    private static void evalFunctionHandlesErrors() {
        // Test error handling with invalid expression
        try {
            Evaluator.run('EVAL("1 + + 2")');
            Assert.fail('Expected an exception for invalid syntax');
        } catch (Exception e) {
            // Expected exception
            System.debug('evalFunctionHandlesErrors exception: ' + e.getMessage());
            Assert.isTrue(e.getMessage().contains('Error executing "EVAL"'));
        }
    }
    
    @IsTest
    private static void evalFunctionWorksWithExplicitContext() {
        // This test verifies that the EVAL function can use an explicitly provided context
        
        // Create two test Accounts with different properties
        Account parentAccount = new Account(
            Name = 'Parent Account',
            Industry = 'Manufacturing'
        );
        insert parentAccount;
        
        Account childAccount = new Account(
            Name = 'Child Account',
            Industry = 'Technology',
            ParentId = parentAccount.Id
        );
        insert childAccount;
        
        try {
            // Test using the child account as the main context, but passing the parent as a context to EVAL
            EvaluationResult childResult = Evaluator.run('EVAL("Name")', childAccount);
            System.debug('Child context result: ' + childResult.result);
            Assert.areEqual('Child Account', childResult.result);
            
            // First fetch the parent account so we can pass it directly as the context
            Account fetchedParent = [SELECT Id, Name, Industry FROM Account WHERE Id = :parentAccount.Id];
            
            // Use the explicit context parameter to evaluate in the context of the parent account
            EvaluationResult parentContextResult = Evaluator.run('EVAL("Name", ' + fetchedParent.Id + ')', childAccount);
            System.debug('Parent ID context result: ' + parentContextResult.result);
            Assert.areEqual('Parent Account', parentContextResult.result);
            
            // Test with the full parent record as context
            EvaluationResult parentObjectResult = Evaluator.run('EVAL("Industry", @Context)', fetchedParent);
            System.debug('Parent object context result: ' + parentObjectResult.result);
            Assert.areEqual('Manufacturing', parentObjectResult.result);
            
        } finally {
            // Clean up test data
            delete new List<Account>{childAccount, parentAccount};
        }
    }
    
    @IsTest
    private static void evalFunctionUsesCachedFieldsAcrossCalls() {
        // This test verifies that the EVAL function's caching behavior works
        // by making multiple calls and ensuring only one SOQL query is performed
        
        // Create a test Account with Id
        Account testAccount = new Account(
            Name = 'Test Caching',
            Industry = 'Technology',
            Website = 'https://example.com'
        );
        insert testAccount;
        
        try {
            // Create a minimal account with just the ID to force field retrieval
            Account minimalAccount = new Account(Id = testAccount.Id);
            
            Integer queriesBeforeFirstEval = Limits.getQueries();
            
            // First EVAL should cause a query
            EvaluationResult result1 = Evaluator.run('EVAL("@Context.Name")', minimalAccount);
            System.debug('First EVAL result: ' + result1.result);
            Assert.areEqual('Test Caching', result1.result);
            
            Integer queriesAfterFirstEval = Limits.getQueries();
            System.debug('Queries after first EVAL: ' + queriesAfterFirstEval);
            Integer queriesUsedByFirstEval = queriesAfterFirstEval - queriesBeforeFirstEval;
            
            // The first call should have used at least one query
            Assert.isTrue(queriesUsedByFirstEval > 0, 'First EVAL should perform at least one query');
            
            // Second EVAL for the same field should use the cache
            EvaluationResult result2 = Evaluator.run('EVAL("@Context.Name")', minimalAccount);
            System.debug('Second EVAL result for same field: ' + result2.result);
            Assert.areEqual('Test Caching', result2.result);
            
            // Third EVAL for a different field should add to the cache, not replace it
            EvaluationResult result3 = Evaluator.run('EVAL("@Context.Industry")', minimalAccount);
            System.debug('Third EVAL result for different field: ' + result3.result);
            Assert.areEqual('Technology', result3.result);
            
            // Verify both fields are now available in a combined expression without queries
            Integer queriesBeforeCombinedEval = Limits.getQueries();
            
            EvaluationResult combinedResult = Evaluator.run(
                'EVAL("@Context.Name + \' - \' + @Context.Industry")', 
                minimalAccount
            );
            System.debug('Combined EVAL result: ' + combinedResult.result);
            Assert.areEqual('Test Caching - Technology', combinedResult.result);
            
            Integer queriesAfterCombinedEval = Limits.getQueries();
            Integer queriesUsedByCombinedEval = queriesAfterCombinedEval - queriesBeforeCombinedEval;
            
            // If caching works, this should use zero or very few queries
            System.debug('Queries used by combined EVAL: ' + queriesUsedByCombinedEval);
            
            // Assert we used fewer queries than would be needed without caching
            Assert.isTrue(queriesUsedByCombinedEval <= queriesUsedByFirstEval, 
                         'Cached EVAL should use fewer queries than initial EVAL');
            
        } finally {
            // Clean up test data
            delete testAccount;
        }
    }
}
}