import { LightningElement, track } from 'lwc';
import getAvailableTemplates  from '@salesforce/apex/DocGenController.getAvailableTemplates';
import getContracts            from '@salesforce/apex/DocGenController.getContracts';
import getSubscriptionPreview  from '@salesforce/apex/DocGenController.getSubscriptionPreview';
import generateDocument        from '@salesforce/apex/DocGenController.generateDocument';

const GROUP_BY_OPTIONS = [
    { label: 'Group by Site (SiteNamelabel__c)', value: 'Site'    },
    { label: 'Group by Product',                 value: 'Product' }
];

const fmt = (val) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val ?? 0);

export default class DocGenWizard extends LightningElement {

    @track currentStep         = '1';
    @track contracts           = [];
    @track selectedContractIds = [];
    @track groupBy             = 'Site';
    @track previewGroups       = [];
    @track templateOptions     = [];
    @track selectedTemplateId  = '';
    @track downloadUrl         = '';
    @track isLoading           = false;
    @track errorMessage        = '';

    groupByOptions = GROUP_BY_OPTIONS;

    /* ─── Lifecycle ─────────────────────────────────────────────── */

    connectedCallback() {
        this.loadContracts('');
        this.loadTemplates();
    }

    /* ─── Data loading ──────────────────────────────────────────── */

    loadContracts(searchTerm) {
        getContracts({ searchTerm })
            .then(result => { this.contracts = result; })
            .catch(err   => { this.errorMessage = this.extractError(err); });
    }

    loadTemplates() {
        getAvailableTemplates()
            .then(result => {
                this.templateOptions = result.map(t => ({ label: t.Name, value: t.Id }));
            })
            .catch(err => { this.errorMessage = this.extractError(err); });
    }

    /* ─── Step 1 handlers ───────────────────────────────────────── */

    handleSearch(event) {
        this.loadContracts(event.target.value);
    }

    handleContractToggle(event) {
        const id  = event.currentTarget.dataset.id;
        const idx = this.selectedContractIds.indexOf(id);
        if (idx >= 0) {
            this.selectedContractIds = this.selectedContractIds.filter(x => x !== id);
        } else {
            this.selectedContractIds = [...this.selectedContractIds, id];
        }
    }

    /* ─── Step 2 handlers ───────────────────────────────────────── */

    handleGroupByChange(event) {
        this.groupBy = event.detail.value;
    }

    /* ─── Step 3 — preview ──────────────────────────────────────── */

    loadPreview() {
        this.isLoading    = true;
        this.currentStep  = '3';
        this.errorMessage = '';

        getSubscriptionPreview({
            contractIds: this.selectedContractIds,
            groupBy:     this.groupBy
        })
        .then(result => {
            this.previewGroups = result.map(grp => ({
                ...grp,
                groupTotalFormatted: fmt(grp.groupTotal),
                lines: grp.lines.map(ln => ({
                    ...ln,
                    netPriceFormatted:  fmt(ln.netPrice),
                    listPriceFormatted: fmt(ln.listPrice)
                }))
            }));
            this.isLoading = false;
        })
        .catch(err => {
            this.errorMessage = this.extractError(err);
            this.isLoading    = false;
            this.currentStep  = '2';
        });
    }

    /* ─── Step 4 handlers ───────────────────────────────────────── */

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    generateDocument() {
        this.isLoading    = true;
        this.errorMessage = '';

        generateDocument({
            contractIds: this.selectedContractIds,
            groupBy:     this.groupBy,
            templateId:  this.selectedTemplateId
        })
        .then(url => {
            this.downloadUrl = url;
            this.isLoading   = false;
        })
        .catch(err => {
            this.errorMessage = this.extractError(err);
            this.isLoading    = false;
        });
    }

    /* ─── Navigation ────────────────────────────────────────────── */

    goToStep1() { this.currentStep = '1'; }
    goToStep2() { this.currentStep = '2'; }
    goToStep3() { this.currentStep = '3'; }
    goToStep4() { this.currentStep = '4'; }

    clearError() { this.errorMessage = ''; }

    reset() {
        this.currentStep         = '1';
        this.selectedContractIds = [];
        this.previewGroups       = [];
        this.selectedTemplateId  = '';
        this.downloadUrl         = '';
        this.errorMessage        = '';
        this.loadContracts('');
    }

    /* ─── Getters ───────────────────────────────────────────────── */

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    get noContractsSelected() { return this.selectedContractIds.length === 0; }
    get noTemplateSelected()  { return !this.selectedTemplateId; }
    get noContracts()         { return this.contracts.length === 0; }
    get selectedCount()       { return this.selectedContractIds.length; }

    get grandTotalFormatted() {
        const total = this.previewGroups.reduce((sum, g) => sum + (g.groupTotal ?? 0), 0);
        return fmt(total);
    }

    get contractsWithSelection() {
        return this.contracts.map(c => ({
            ...c,
            isSelected: this.selectedContractIds.includes(c.Id),
            rowClass: 'docgen-contract-row' +
                      (this.selectedContractIds.includes(c.Id) ? ' selected' : '')
        }));
    }

    /* ─── Helpers ───────────────────────────────────────────────── */

    extractError(err) {
        return err?.body?.message ?? err?.message ?? 'An unexpected error occurred.';
    }
}
