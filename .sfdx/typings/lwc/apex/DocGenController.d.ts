declare module "@salesforce/apex/DocGenController.getGroupByOptions" {
  export default function getGroupByOptions(): Promise<any>;
}
declare module "@salesforce/apex/DocGenController.getAvailableTemplates" {
  export default function getAvailableTemplates(): Promise<any>;
}
declare module "@salesforce/apex/DocGenController.getContracts" {
  export default function getContracts(param: {searchTerm: any}): Promise<any>;
}
declare module "@salesforce/apex/DocGenController.getSubscriptionPreview" {
  export default function getSubscriptionPreview(param: {contractIds: any, groupByField: any}): Promise<any>;
}
declare module "@salesforce/apex/DocGenController.generateDocument" {
  export default function generateDocument(param: {contractIds: any, groupByField: any, templateId: any}): Promise<any>;
}
