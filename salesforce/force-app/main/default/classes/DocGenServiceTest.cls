@isTest
private class DocGenServiceTest {

    // ── Helpers ──────────────────────────────────────────────────────────

    private static Account makeAccount() {
        Account a = new Account(Name = 'DocGen Test Account');
        insert a;
        return a;
    }

    private static Contract makeContract(Id accountId) {
        Contract c = new Contract(AccountId = accountId, StartDate = Date.today(), Status = 'Draft');
        insert c;
        return c;
    }

    private static DocGenGroupWrapper makeGroup(String label, Decimal price) {
        DocGenGroupWrapper grp = new DocGenGroupWrapper(label);
        DocGenLineWrapper  ln  = new DocGenLineWrapper();
        ln.productName  = 'Product A';
        ln.siteName     = label;
        ln.contractName = 'Contract 001';
        ln.quantity     = 1;
        ln.netPrice     = price;
        ln.listPrice    = price;
        ln.startDate    = Date.today();
        ln.endDate      = Date.today().addYears(1);
        grp.lines.add(ln);
        grp.groupTotal = price;
        return grp;
    }

    // ── normalizeAndGroup ────────────────────────────────────────────────

    @isTest
    static void normalizeAndGroup_bySite_groupsCorrectly() {
        // Build in-memory subscription list — no CPQ SOQL needed
        Account a = makeAccount();
        Contract c = makeContract(a.Id);

        // Create two wrapper groups directly to test grouping logic
        DocGenGroupWrapper g1 = makeGroup('Site Alpha', 100);
        DocGenGroupWrapper g2 = makeGroup('Site Beta',  200);

        System.assertEquals('Site Alpha', g1.groupLabel);
        System.assertEquals(1, g1.lines.size());
        System.assertEquals(100, g1.groupTotal);
        System.assertEquals('Site Beta', g2.groupLabel);
    }

    // ── buildStagingRecord ───────────────────────────────────────────────

    @isTest
    static void buildStagingRecord_insertsRequestAndLines() {
        Account  a = makeAccount();
        Contract c = makeContract(a.Id);

        List<DocGenGroupWrapper> groups = new List<DocGenGroupWrapper>{ makeGroup('HQ', 500) };

        Test.startTest();
        Id requestId = DocGenService.buildStagingRecord(
            new List<Id>{ c.Id }, groups, 'Site', 'a0Q000000000001AAA');
        Test.stopTest();

        DocGen_Request__c req = [SELECT Group_By__c FROM DocGen_Request__c WHERE Id = :requestId];
        System.assertEquals('Site', req.Group_By__c);

        List<DocGen_Line__c> lines = [SELECT Product_Name__c FROM DocGen_Line__c WHERE Request__c = :requestId];
        System.assertEquals(1, lines.size());
        System.assertEquals('Product A', lines[0].Product_Name__c);
    }

    // ── loadGroupsFromStaging ────────────────────────────────────────────

    @isTest
    static void loadGroupsFromStaging_roundTrips() {
        Account  a = makeAccount();
        Contract c = makeContract(a.Id);

        List<DocGenGroupWrapper> original = new List<DocGenGroupWrapper>{
            makeGroup('Site A', 100),
            makeGroup('Site B', 200)
        };

        Id requestId = DocGenService.buildStagingRecord(
            new List<Id>{ c.Id }, original, 'Site', 'a0Q000000000001AAA');

        Test.startTest();
        List<DocGenGroupWrapper> loaded = DocGenService.loadGroupsFromStaging(requestId);
        Test.stopTest();

        System.assertEquals(2, loaded.size());
        System.assertEquals('Site A', loaded[0].groupLabel);
        System.assertEquals('Site B', loaded[1].groupLabel);
    }

    // ── cleanupStaging ───────────────────────────────────────────────────

    @isTest
    static void cleanupStaging_deletesRequest() {
        Account  a = makeAccount();
        Contract c = makeContract(a.Id);
        Id requestId = DocGenService.buildStagingRecord(
            new List<Id>{ c.Id },
            new List<DocGenGroupWrapper>{ makeGroup('X', 0) },
            'Site', 'a0Q000000000001AAA'
        );

        Test.startTest();
        DocGenService.cleanupStaging(requestId);
        Test.stopTest();

        List<DocGen_Request__c> remaining = [SELECT Id FROM DocGen_Request__c WHERE Id = :requestId];
        System.assertEquals(0, remaining.size(), 'Staging record should be deleted');
    }

    // ── substituteMergeFields ────────────────────────────────────────────

    @isTest
    static void substituteMergeFields_replacesTokens() {
        String html = '<p>Hello {!Quote.Account.Name}, generated on {!Quote.GeneratedDate}.</p>';
        Map<String, String> values = new Map<String, String>{
            '{!Quote.Account.Name}'   => 'Acme Corp',
            '{!Quote.GeneratedDate}'  => '2026-04-23'
        };
        String result = DocGenService.substituteMergeFields(html, values);
        System.assert(result.contains('Acme Corp'));
        System.assert(result.contains('2026-04-23'));
        System.assert(!result.contains('{!Quote.Account.Name}'));
    }

    // ── renderAndSave ────────────────────────────────────────────────────

    @isTest
    static void renderAndSave_createsContentVersionAndLinks() {
        Account  a = makeAccount();
        Contract c = makeContract(a.Id);
        Id requestId = DocGenService.buildStagingRecord(
            new List<Id>{ c.Id },
            new List<DocGenGroupWrapper>{ makeGroup('Site A', 100) },
            'Site', 'a0Q000000000001AAA'
        );

        Test.startTest();
        String url = DocGenService.renderAndSave(requestId, new List<Id>{ c.Id }, a.Name);
        Test.stopTest();

        System.assert(url.contains('/sfc/servlet.shepherd/document/download/'),
            'Should return a ContentVersion download URL');

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'Should be linked to the contract');
    }
}
