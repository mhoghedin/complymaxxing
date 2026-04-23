public class ContractRenewalConfig {
    public String finalizedStatus { get; private set; }
    public String jobCron { get; private set; }
    public Integer queryLimit { get; private set; }

    public static ContractRenewalConfig load() {
        if (mockInstance != null) return mockInstance;
        List<ContractRenewalConfig__mdt> records = [
            SELECT Finalized_Status__c, Job_Cron__c, Query_Limit__c
            FROM ContractRenewalConfig__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (records.isEmpty()) {
            throw new ContractRenewalException(
                'ContractRenewalConfig.Default Custom Metadata record not found. ' +
                'Deploy the metadata and set Finalized_Status__c before running this job.'
            );
        }
        ContractRenewalConfig__mdt record = records[0];
        ContractRenewalConfig cfg = new ContractRenewalConfig();
        cfg.finalizedStatus = record.Finalized_Status__c;
        cfg.jobCron = record.Job_Cron__c;
        cfg.queryLimit = record.Query_Limit__c != null ? (Integer) record.Query_Limit__c : 2000;
        return cfg;
    }

    @TestVisible private static ContractRenewalConfig mockInstance;

    @TestVisible
    static ContractRenewalConfig forTest(String finalizedStatus) {
        ContractRenewalConfig cfg = new ContractRenewalConfig();
        cfg.finalizedStatus = finalizedStatus;
        cfg.jobCron = '0 0 2 * * ?';
        cfg.queryLimit = 2000;
        mockInstance = cfg;
        return cfg;
    }

    private ContractRenewalConfig() {}

    public class ContractRenewalException extends Exception {}
}
