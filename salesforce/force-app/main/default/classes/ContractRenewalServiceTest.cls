@isTest
private class ContractRenewalServiceTest {

    private class MockRenewalApi implements IRenewalApi {
        public Id returnOppId;
        public List<Id> capturedIds;
        MockRenewalApi(Id returnOppId) { this.returnOppId = returnOppId; }
        public Id renewContracts(List<Id> contractIds, Id masterContractId) {
            capturedIds = contractIds;
            return returnOppId;
        }
    }

    private static Account makeAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Opportunity makeOpp(Id accountId) {
        Opportunity o = new Opportunity(
            Name = 'Test Renewal Opp',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addYears(1)
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

    @isTest
    static void groupContracts_groupsByAccountAndDate() {
        Account a1 = makeAccount('Acct 1');
        Account a2 = makeAccount('Acct 2');
        Date d1 = Date.today().addYears(1);
        Date d2 = Date.today().addYears(2);

        List<Contract> contracts = new List<Contract>{
            new Contract(AccountId = a1.Id, Expiration_Date__c = d1),
            new Contract(AccountId = a1.Id, Expiration_Date__c = d1),
            new Contract(AccountId = a1.Id, Expiration_Date__c = d2),
            new Contract(AccountId = a2.Id, Expiration_Date__c = d1)
        };

        List<String> fields = new List<String>{ 'AccountId', 'Expiration_Date__c' };
        Map<String, List<Contract>> groups = ContractRenewalService.groupContracts(contracts, fields);

        System.assertEquals(3, groups.size(), 'Expected 3 distinct groups');
        String key = a1.Id + '_' + d1;
        System.assertEquals(2, groups.get(key).size(), 'Expected 2 contracts in a1/d1 group');
    }

    @isTest
    static void groupContracts_segmentFieldSplitsWithinSameAccountAndDate() {
        Account a = makeAccount('Acct');
        Date d = Date.today().addYears(1);

        List<Contract> contracts = new List<Contract>{
            new Contract(AccountId = a.Id, Expiration_Date__c = d, Renewal_Segment__c = 'Commercial'),
            new Contract(AccountId = a.Id, Expiration_Date__c = d, Renewal_Segment__c = 'International'),
            new Contract(AccountId = a.Id, Expiration_Date__c = d, Renewal_Segment__c = 'Commercial')
        };

        List<String> fields = new List<String>{ 'AccountId', 'Expiration_Date__c', 'Renewal_Segment__c' };
        Map<String, List<Contract>> groups = ContractRenewalService.groupContracts(contracts, fields);

        System.assertEquals(2, groups.size(), 'Expected 2 groups split by segment');
        String commKey = a.Id + '_' + d + '_Commercial';
        System.assertEquals(2, groups.get(commKey).size(), 'Expected 2 Commercial contracts');
    }

    @isTest
    static void buildGroupKey_returnsFieldsJoinedByUnderscore() {
        Account a = makeAccount('Acct');
        Date d = Date.today();
        Contract c = new Contract(AccountId = a.Id, Expiration_Date__c = d, Renewal_Segment__c = 'Provider');

        String key = ContractRenewalService.buildGroupKey(c,
            new List<String>{ 'AccountId', 'Expiration_Date__c', 'Renewal_Segment__c' });

        System.assertEquals(a.Id + '_' + d + '_Provider', key);
    }

    @isTest
    static void processGroup_firstTime_setsRenewalOppOnContracts() {
        Account a = makeAccount('Test');
        Contract c = makeContract(a.Id, Date.today().addYears(1));
        Opportunity mockOpp = makeOpp(a.Id);

        ContractRenewalService.renewApi = new MockRenewalApi(mockOpp.Id);

        Test.startTest();
        ContractRenewalService.processGroup(new List<Id>{ c.Id }, null, c.Id);
        Test.stopTest();

        Contract updated = [SELECT SBQQ__RenewalOpportunity__c FROM Contract WHERE Id = :c.Id];
        System.assertEquals(mockOpp.Id, updated.SBQQ__RenewalOpportunity__c);
    }

    @isTest
    static void processGroup_existingOpp_deletesNewOppAndPointsToExisting() {
        Account a = makeAccount('Test');
        Contract c = makeContract(a.Id, Date.today().addYears(1));
        Opportunity existingOpp = makeOpp(a.Id);
        Opportunity newOpp = makeOpp(a.Id);

        ContractRenewalService.renewApi = new MockRenewalApi(newOpp.Id);

        Test.startTest();
        ContractRenewalService.processGroup(new List<Id>{ c.Id }, existingOpp.Id, c.Id);
        Test.stopTest();

        Contract updated = [SELECT SBQQ__RenewalOpportunity__c FROM Contract WHERE Id = :c.Id];
        System.assertEquals(existingOpp.Id, updated.SBQQ__RenewalOpportunity__c, 'Should point to existing opp');

        List<Opportunity> shouldBeDeleted = [SELECT Id FROM Opportunity WHERE Id = :newOpp.Id];
        System.assertEquals(0, shouldBeDeleted.size(), 'New opp should have been deleted');
    }
}
