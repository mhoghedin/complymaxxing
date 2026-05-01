@isTest
private class ContractRenewalConfigTest {

    @isTest
    static void forTest_defaultsGroupingFieldsToAccountIdAndExpirationDate() {
        ContractRenewalConfig cfg = ContractRenewalConfig.forTest('Contracted');

        System.assertEquals('Contracted', cfg.finalizedStatus);
        System.assertEquals(2000, cfg.queryLimit);
        System.assertEquals(2, cfg.groupingFields.size());
        System.assertEquals('AccountId', cfg.groupingFields[0]);
        System.assertEquals('Expiration_Date__c', cfg.groupingFields[1]);
    }

    @isTest
    static void forTest_customGroupingFields_usesProvidedList() {
        List<String> fields = new List<String>{ 'AccountId', 'Expiration_Date__c', 'Renewal_Segment__c' };
        ContractRenewalConfig cfg = ContractRenewalConfig.forTest('Active', fields);

        System.assertEquals('Active', cfg.finalizedStatus);
        System.assertEquals(3, cfg.groupingFields.size());
        System.assertEquals('Renewal_Segment__c', cfg.groupingFields[2]);
    }

    @isTest
    static void load_missingRecord_throwsException() {
        ContractRenewalConfig.mockInstance = null;
        // Without a deployed Default CMDT record the query returns empty — expect the exception
        try {
            ContractRenewalConfig.load();
            System.assert(false, 'Expected ContractRenewalException');
        } catch (ContractRenewalConfig.ContractRenewalException e) {
            System.assert(e.getMessage().contains('not found'), 'Exception message should mention missing record');
        }
    }
}
