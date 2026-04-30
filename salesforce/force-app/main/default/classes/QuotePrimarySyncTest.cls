@isTest
private class QuotePrimarySyncTest {

    // No CPQ data in tests, verifies the isEmpty guard and job completes without throwing
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
        // No exception = pass
    }
}
