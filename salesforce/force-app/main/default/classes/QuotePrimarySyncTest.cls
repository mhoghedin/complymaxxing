@isTest
private class QuotePrimarySyncTest {

    // CPQ quotes are not available in unit tests, so the SOQL returns no rows.
    // This verifies the isEmpty guard works and the job completes without throwing.
    @isTest
    static void execute_noQuoteFound_completesCleanly() {
        Account a = new Account(Name = 'Test');
        insert a;
        Opportunity fakeQuoteId = new Opportunity(
            Name = 'FakeQuote', AccountId = a.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addYears(1)
        );
        insert fakeQuoteId;

        Test.startTest();
        System.schedule(
            'Test_QuotePrimarySync',
            '0 0 3 * * ?',
            new QuotePrimarySync(fakeQuoteId.Id)
        );
        Test.stopTest();
        // No exception = pass; CPQ DML is a no-op without managed package data
    }
}
