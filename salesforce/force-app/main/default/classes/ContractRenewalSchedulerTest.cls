@isTest
private class ContractRenewalSchedulerTest {

    private class MockRenewalApi implements IRenewalApi {
        public Id returnOppId;
        MockRenewalApi(Id returnOppId) { this.returnOppId = returnOppId; }
        public Id renewContracts(List<Id> contractIds) { return returnOppId; }
    }

    // Returns a different opp ID on each call — proves groups are processed separately
    private class SequentialMockRenewalApi implements IRenewalApi {
        private List<Id> returnIds;
        private Integer callCount = 0;
        SequentialMockRenewalApi(List<Id> returnIds) { this.returnIds = returnIds; }
        public Id renewContracts(List<Id> contractIds) { return returnIds[callCount++]; }
    }

    private static Account makeAccount() {
        Account a = new Account(Name = 'Test');
        insert a;
        return a;
    }

    private static Opportunity makeOpp(Id accountId) {
        Opportunity o = new Opportunity(
            Name = 'Renewal', AccountId = accountId,
            StageName = 'Prospecting', CloseDate = Date.today().addYears(1)
        );
        insert o;
        return o;
    }

    private static Contract makeContract(Id accountId, Date expirationDate) {
        Contract c = new Contract(AccountId = accountId, StartDate = Date.today(), Status = 'Draft');
        insert c;
        c.Expiration_Date__c = expirationDate;
        update c;
        return c;
    }

    // --- No contracts ---

    @isTest
    static void execute_noContracts_doesNothing() {
        ContractRenewalConfig.forTest('Fully Executed');
        ContractRenewalScheduler.testContracts = new List<Contract>();

        Test.startTest();
        new ContractRenewalScheduler().execute(null);
        Test.stopTest();
        // No exception = pass
    }

    // --- Single group, first run ---

    @isTest
    static void execute_singleGroup_createsRenewal() {
        Account a = makeAccount();
        Opportunity mockOpp = makeOpp(a.Id);
        Date expDate = Date.today().addYears(1);
        Contract c1 = makeContract(a.Id, expDate);
        Contract c2 = makeContract(a.Id, expDate);

        ContractRenewalConfig.forTest('Fully Executed');
        ContractRenewalService.renewApi = new MockRenewalApi(mockOpp.Id);

        // Inject contracts to bypass CPQ-field SOQL
        ContractRenewalScheduler.testContracts = new List<Contract>{
            new Contract(Id = c1.Id, AccountId = a.Id, Expiration_Date__c = expDate, Renewal_Opportunity__c = null),
            new Contract(Id = c2.Id, AccountId = a.Id, Expiration_Date__c = expDate, Renewal_Opportunity__c = null)
        };

        Test.startTest();
        new ContractRenewalScheduler().execute(null);
        Test.stopTest();

        List<Contract> updated = [SELECT Renewal_Opportunity__c FROM Contract WHERE Id IN :new List<Id>{c1.Id, c2.Id}];
        for (Contract c : updated) {
            System.assertEquals(mockOpp.Id, c.Renewal_Opportunity__c, 'Each contract should point to the renewal opp');
        }
    }

    // --- Two groups — confirms each group is processed as an independent renewal ---

    @isTest
    static void execute_twoGroups_processesEachSeparately() {
        Account a1 = makeAccount();
        Account a2 = new Account(Name = 'Test 2');
        insert a2;

        Opportunity opp1 = makeOpp(a1.Id);
        Opportunity opp2 = makeOpp(a2.Id);
        Date expDate = Date.today().addYears(1);

        Contract c1 = makeContract(a1.Id, expDate);
        Contract c2 = makeContract(a2.Id, expDate);

        // Sequential mock returns opp1 on first call, opp2 on second.
        // If grouping is working, c1 and c2 must end up on different renewal opps.
        ContractRenewalService.renewApi = new SequentialMockRenewalApi(new List<Id>{ opp1.Id, opp2.Id });
        ContractRenewalConfig.forTest('Fully Executed');

        ContractRenewalScheduler.testContracts = new List<Contract>{
            new Contract(Id = c1.Id, AccountId = a1.Id, Expiration_Date__c = expDate, Renewal_Opportunity__c = null),
            new Contract(Id = c2.Id, AccountId = a2.Id, Expiration_Date__c = expDate, Renewal_Opportunity__c = null)
        };

        Test.startTest();
        new ContractRenewalScheduler().execute(null);
        Test.stopTest();

        Contract updated1 = [SELECT Renewal_Opportunity__c FROM Contract WHERE Id = :c1.Id];
        Contract updated2 = [SELECT Renewal_Opportunity__c FROM Contract WHERE Id = :c2.Id];

        System.assertNotEquals(null, updated1.Renewal_Opportunity__c, 'c1 should have a renewal opp');
        System.assertNotEquals(null, updated2.Renewal_Opportunity__c, 'c2 should have a renewal opp');
        System.assertNotEquals(
            updated1.Renewal_Opportunity__c,
            updated2.Renewal_Opportunity__c,
            'Two separate accounts must produce two separate renewal opps'
        );
    }

    // --- Scheduling ---

    @isTest
    static void schedule_registersSuccessfully() {
        ContractRenewalConfig.forTest('Fully Executed');
        ContractRenewalScheduler.testContracts = new List<Contract>();

        Test.startTest();
        String jobId = System.schedule(
            'Test Contract Renewal Merger',
            '0 0 2 * * ?',
            new ContractRenewalScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should register without error');
    }
}
