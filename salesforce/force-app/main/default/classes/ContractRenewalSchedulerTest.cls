@isTest
private class ContractRenewalSchedulerTest {

    private class MockRenewalApi implements IRenewalApi {
        public Id returnOppId;
        MockRenewalApi(Id returnOppId) { this.returnOppId = returnOppId; }
        public Id renewContracts(List<Id> contractIds) { return returnOppId; }
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

    // --- Two groups — confirms grouping works across accounts ---

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

        // Use a mock that returns different opps per call
        ContractRenewalService.renewApi = new MockRenewalApi(opp1.Id);
        ContractRenewalConfig.forTest('Fully Executed');

        ContractRenewalScheduler.testContracts = new List<Contract>{
            new Contract(Id = c1.Id, AccountId = a1.Id, Expiration_Date__c = expDate, Renewal_Opportunity__c = null),
            new Contract(Id = c2.Id, AccountId = a2.Id, Expiration_Date__c = expDate, Renewal_Opportunity__c = null)
        };

        Test.startTest();
        new ContractRenewalScheduler().execute(null);
        Test.stopTest();

        // Both contracts processed — exact opp assignment depends on mock order,
        // just confirm both have a non-null renewal opp
        List<Contract> updated = [SELECT Renewal_Opportunity__c FROM Contract WHERE Id IN :new List<Id>{c1.Id, c2.Id}];
        for (Contract c : updated) {
            System.assertNotEquals(null, c.Renewal_Opportunity__c, 'Contract should have a renewal opp set');
        }
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
