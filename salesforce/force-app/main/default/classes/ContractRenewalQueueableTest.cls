@isTest
private class ContractRenewalQueueableTest {

    private class MockRenewalApi implements IRenewalApi {
        public Id returnOppId;
        MockRenewalApi(Id returnOppId) { this.returnOppId = returnOppId; }
        public Id renewContracts(List<Id> contractIds, Id masterContractId) { return returnOppId; }
    }

    private class ErrorRenewalApi implements IRenewalApi {
        public Id renewContracts(List<Id> contractIds, Id masterContractId) {
            throw new System.CalloutException('Simulated CPQ failure');
        }
    }

    private static Account makeAccount() {
        Account a = new Account(Name = 'Test');
        insert a;
        return a;
    }

    private static Contract makeContract(Id accountId) {
        Contract c = new Contract(AccountId = accountId, StartDate = Date.today(), Status = 'Draft');
        insert c;
        return c;
    }

    @isTest
    static void execute_success_setsRenewalOpportunity() {
        Account a = makeAccount();
        Contract c = makeContract(a.Id);
        Opportunity mockOpp = new Opportunity(
            Name = 'Renewal', AccountId = a.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addYears(1)
        );
        insert mockOpp;

        ContractRenewalService.renewApi = new MockRenewalApi(mockOpp.Id);

        List<List<Id>> groups = new List<List<Id>>{ new List<Id>{ c.Id } };
        List<Id> existingOpps = new List<Id>{ null };
        List<Id> masterIds = new List<Id>{ c.Id };

        Test.startTest();
        System.enqueueJob(new ContractRenewalQueueable(groups, existingOpps, masterIds, 0));
        Test.stopTest();

        Contract updated = [SELECT SBQQ__RenewalOpportunity__c FROM Contract WHERE Id = :c.Id];
        System.assertEquals(mockOpp.Id, updated.SBQQ__RenewalOpportunity__c);
    }

    @isTest
    static void execute_onError_writesRenewalErrorAndContinues() {
        Account a = makeAccount();
        Contract c = makeContract(a.Id);

        ContractRenewalService.renewApi = new ErrorRenewalApi();

        List<List<Id>> groups = new List<List<Id>>{ new List<Id>{ c.Id } };
        List<Id> existingOpps = new List<Id>{ null };
        List<Id> masterIds = new List<Id>{ c.Id };

        Test.startTest();
        System.enqueueJob(new ContractRenewalQueueable(groups, existingOpps, masterIds, 0));
        Test.stopTest();

        Contract updated = [SELECT Renewal_Error__c FROM Contract WHERE Id = :c.Id];
        System.assertNotEquals(null, updated.Renewal_Error__c, 'Error message should be written to contract');
        System.assert(updated.Renewal_Error__c.contains('Simulated CPQ failure'));
    }
}
