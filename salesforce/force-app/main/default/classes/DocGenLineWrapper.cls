public class DocGenLineWrapper {
    @AuraEnabled public String  productName  { get; set; }
    @AuraEnabled public String  siteName     { get; set; }
    @AuraEnabled public String  contractName { get; set; }
    @AuraEnabled public Decimal quantity     { get; set; }
    @AuraEnabled public Decimal netPrice     { get; set; }
    @AuraEnabled public Decimal listPrice    { get; set; }
    @AuraEnabled public Date    startDate    { get; set; }
    @AuraEnabled public Date    endDate      { get; set; }

    public DocGenLineWrapper() {}

    public DocGenLineWrapper(SBQQ__Subscription__c sub) {
        this.productName  = sub.SBQQ__ProductName__c;
        this.siteName     = (String) sub.get('SiteNamelabel__c');
        this.contractName = sub.SBQQ__Contract__r.Name;
        this.quantity     = sub.SBQQ__Quantity__c;
        this.netPrice     = sub.SBQQ__CustomerPrice__c;
        this.listPrice    = sub.SBQQ__RegularPrice__c;
        this.startDate    = sub.SBQQ__StartDate__c;
        this.endDate      = sub.SBQQ__EndDate__c;
    }
}
