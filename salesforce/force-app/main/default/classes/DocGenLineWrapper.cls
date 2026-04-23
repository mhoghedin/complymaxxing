public class DocGenLineWrapper {
    @AuraEnabled public String productName;
    @AuraEnabled public String siteName;
    @AuraEnabled public String contractName;
    @AuraEnabled public Decimal quantity;
    @AuraEnabled public Decimal netPrice;
    @AuraEnabled public Decimal listPrice;
    @AuraEnabled public Date startDate;
    @AuraEnabled public Date endDate;

    public DocGenLineWrapper() {}

    public DocGenLineWrapper(SBQQ__Subscription__c sub) {
        this.productName  = sub.SBQQ__ProductName__c;
        this.siteName     = sub.SiteNamelabel__c;
        this.contractName = sub.SBQQ__Contract__r.Name;
        this.quantity     = sub.SBQQ__Quantity__c;
        this.netPrice     = sub.SBQQ__CustomerPrice__c;
        this.listPrice    = sub.SBQQ__RegularPrice__c;
        this.startDate    = sub.SBQQ__StartDate__c;
        this.endDate      = sub.SBQQ__EndDate__c;
    }
}
