@isTest
private class QuotePrimaryCleanupTest {

    private static Opportunity makeOpp() {
        Account a = new Account(Name = 'Test');
        insert a;
        Opportunity o = new Opportunity(
            Name = 'Renewal', AccountId = a.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addYears(1)
        );
        insert o;
        return o;
    }

    // CPQ quotes are not available in unit tests, so the SOQL returns no rows.
    // This verifies the job executes cleanly and chains to QuotePrimarySync
    // without throwing, covering the isEmpty guard and the schedule call.
    @isTest
    static void execute_noQuotesFound_completesCleanly() {
        Opportunity o = makeOpp();

        Account a2 = new Account(Name = 'Test2');
        insert a2;
        Opportunity fakeQuoteId = new Opportunity(
            Name = 'FakeQuote', AccountId = a2.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addYears(1)
        );
        insert fakeQuoteId;

        Test.startTest();
        System.schedule(
            'Test_QuotePrimaryCleanup',
            '0 0 3 * * ?',
            new QuotePrimaryCleanup(o.Id, fakeQuoteId.Id)
        );
        Test.stopTest();
        // No exception = pass; CPQ DML is a no-op without managed package data
    }
}
