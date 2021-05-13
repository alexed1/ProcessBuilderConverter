import {LightningElement, api, track, wire} from 'lwc';
import getFlowNamesApex from '@salesforce/apex/FlowListController.getFlowNamesApex';
import getWFRDataApex from '@salesforce/apex/FlowListController.getWFRDataApex';
import {FlowAttributeChangeEvent} from 'lightning/flowSupport';

export default class flowPickerFSC extends LightningElement {
    @api label;
    @api selectedFlowApiName;
    @api showActiveFlowsOnly = false;
    @api searchString;
    @api required;
    @api showWhichFlowTypes = 'Flow,AutolaunchedFlow';
    @api placeholder = '- Select a Flow -';
    @api componentWidth = '6';
    @api targetObject;
    @track flowDefinitions;
    @track wfrDefinitions;

    @wire(getFlowNamesApex, {filtersString: '$filters'})
    _getFlowNamesApex({error, data}) {
    if (error) {
            console.log('error returning from getFlowNamesApex' + error.body.message);
        } else if (data) {
            console.log('returning from getFlowNamesApex with: ' + JSON.stringify(data));
            this.flowDefinitions = data;
        }
    }

    @wire(getWFRDataApex, {})
    _getWFRDataApex({error, data}) {
    if (error) {
            let errortext = 'error returning from _getWFRDataApex' + error.body.message;
            console.log(errortext);
            throw new Error(errortext);
        } else if (data) {
            this.wfrDefinitions = data;
            console.log('got back data from WFR call: ' + JSON.stringify(data));
        }
    }

    // Set the width of the component as a # out of 12
    // 12 = 100% width, 6 = 50% width, 3 = 25%width, etc
    get comboboxWidth() {
        return 'slds-size_' + this.componentWidth + '-of-12 slds-form-element';
    }

    get filters() {
        let filters = new Object();

        if (this.showWhichFlowTypes) {
            filters['ProcessType'] = this.splitValues(this.showWhichFlowTypes);
        }
        if (this.showActiveFlowsOnly) {
            filters['!ActiveVersionId'] = ['null'];
        }
        // Add filter for Search String
        if (this.searchString) {
            filters['Label'] = ["\'%"+this.searchString+"%\'"];
        }
        return JSON.stringify(filters);
    }

    get options() {
        if(this.showWhichFlowTypes == 'WorkflowRules' && this.wfrDefinitions) {
            return this.wfrDefinitions.map(curFD => {
                return {
                    value: curFD,
                    label: curFD
                }
            });
        } else if (this.flowDefinitions && this.showWhichFlowTypes != 'WorkflowRules') {
           
            return this.flowDefinitions.map(curFD => {
                return {
                    value: curFD.ApiName,
                    label: curFD.Label
                }
            });
        } else {
           
            return [];
        }
    }

    //this should be cleaned up and merged with options. there should be a single definitions that gets mapped one way for flows and another way for wfrs. it's all too damn touchy for me so i have it separate
    get options2() {
        console.log ('in options2');
        if (this.wfrDefinitions) {
            console.log('wfrDefinitions: ' + JSON.stringify(this.wfrDefinitions));
            return this.wfrDefinitions.map(curFD => {
                return {
                    value: curFD,
                    label: curFD
                }
            });
        } else {
            console.log('wfrdef empty');
            return [];
        }
    }

    handleChange(event) {
        this.selectedFlowApiName = event.detail.value;
        const attributeChangeEvent = new FlowAttributeChangeEvent('selectedFlowApiName', this.selectedFlowApiName);
        this.dispatchEvent(attributeChangeEvent);
    }

    // This is added to make the selected Flow API Name available to a calling Aura component
    @api
    flowApiName() {
        return this.selectedFlowApiName;
    }

    @api
    validate() {
        if (this.required && !this.selectedFlowApiName) {
            return {
                isValid: false,
                errorMessage: 'Complete this field.'
            };
        } else {
            return {isValid: true};
        }
    }

    splitValues(originalString) {
        if (originalString) {
            return originalString.replace(/ /g, '').split(',');
        } else {
            return [];
        }
    };

}