public class ContractRenewalConfig {
    public String finalizedStatus { get; private set; }
    public String jobCron { get; private set; }

    public static ContractRenewalConfig load() {
        if (mockInstance != null) return mockInstance;
        ContractRenewalConfig__mdt record = [
            SELECT Finalized_Status__c, Job_Cron__c
            FROM ContractRenewalConfig__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        ContractRenewalConfig cfg = new ContractRenewalConfig();
        cfg.finalizedStatus = record.Finalized_Status__c;
        cfg.jobCron = record.Job_Cron__c;
        return cfg;
    }

    @TestVisible private static ContractRenewalConfig mockInstance;

    @TestVisible
    static ContractRenewalConfig forTest(String finalizedStatus) {
        ContractRenewalConfig cfg = new ContractRenewalConfig();
        cfg.finalizedStatus = finalizedStatus;
        cfg.jobCron = '0 0 2 * * ?';
        mockInstance = cfg;
        return cfg;
    }

    private ContractRenewalConfig() {}
}
