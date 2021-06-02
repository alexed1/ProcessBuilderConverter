public with sharing class ValidateWFRMetadata {

    
        public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

        public static String ruleName;
        public static Dom.XMLNode wfrMetadata;
        public static String validityProblemString = '';
        public static List<String> validFieldUpdateNames = new List<String>();

        static final List<String> unsupportedFormulaList = new List<String> {
            'GETRECORDIDS',
            'IMAGE',
            'INCLUDE',
            'PARENTGROUPVAL',
            'PREVGROUPVAL',
            'PRIORVALUE',
            'REQUIRE SCRIPT',
            'TIMENOW',
            'TIMEVALUE',
            'VLOOKUP'
        };

        public static string validateRule(Dom.XMLNode wfrXML, String ruleName) {

            ValidateWFRMetadata.ruleName = ruleName;
            ValidateWFRMetadata.wfrMetadata = wfrXML;               

            //get the matching rules entity. The other ones won't be used
            Dom.XMLNode rulesEntity = getRulesEntity(wfrXML, ruleName.split('\\.')[1]);

            

            //don't currently support time triggers
            if (hasTimeTriggers(rulesEntity) == true)
            ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + 'This converter can not currently convert WorkflowRules with Time Triggers  \n';
    

            //get and validate the corresponding action entities
            List<Dom.XmlNode> actionEntities = getRuleActions(rulesEntity);
            for(Dom.XmlNode actionEntity : actionEntities) {
                validateActionEntity(actionEntity);
            }

            return ValidateWFRMetadata.validityProblemString;
        }

    public static Dom.XmlNode getRulesEntity (Dom.XmlNode wfrXML, String ruleName) {
        System.debug('ruleName ' + ruleName);
        Dom.XmlNode curRule = XmlUtils.getChildNodeByName(wfrXML, 'fullName',  'rules',  ruleName);
        return curRule;

    }

    public static Boolean hasTimeTriggers (Dom.XmlNode rulesEntity) {
        Boolean hasTimeTriggers = false;
        if(rulesEntity.getChildElement('workflowTimeTriggers', SOAP_NS) != null) {
            return true;
        }

        return false;
    }

    //some fieldUpdates use special types or formulas, and are not yet supported
    public static Boolean isValidFieldUpdate(String fieldUpdateName) {
        Boolean isValid = true;

        for(Dom.XmlNode node : ValidateWFRMetadata.wfrMetadata.getChildren()) {
            
            if(node.getName() == 'fieldUpdates' && node.getChildElement('fullName', SOAP_NS).getText() == fieldUpdateName) {
                String operation = node.getChildElement('operation', SOAP_NS).getText();
                if(( operation == 'Formula' && !isSupportedFormula(node))){
                    ValidateWFRMetadata.validityProblemString += '\n At least one formula in the target workflow rule includes a function that is not currently supported in Flow. See https://help.salesforce.com/articleView?id=sf.flow_considerations_design_formulas.htm&type=5';
                    isValid = false;
                } else if (node.getChildElement('reevaluateOnChange', SOAP_NS) != null && node.getChildElement('reevaluateOnChange', SOAP_NS).getText() == 'true'){
                    ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + ' \n This rule has action with reevaluateOnChange ';
                    isValid = false;
                }
                
            }
        }
        
        return isValid;

    }

    static Boolean isSupportedFormula(Dom.XmlNode node) {

        String value = node.getChildElement('formula', SOAP_NS).getText();
        if(String.isNotEmpty(value)) {
            for(String unsupportedFormula : unsupportedFormulaList) {
                if(value.contains(unsupportedFormula)) {
                    ValidateWFRMetadata.validityProblemString += '\n At least one formula in the target workflow rule includes a function that is not currently supported in Flow. See https://help.salesforce.com/articleView?id=sf.flow_considerations_design_formulas.htm&type=5';
                    return false;
                }
            }
        }

        return true;
    }

    public static String getActionType(Dom.XmlNode actionEntity) {
        String type = actionEntity.getChildElement('type', SOAP_NS).getText();
        System.debug('type ' + type);
        return type;
    }

    public static String getActionName(Dom.XmlNode actionEntity) {

        String name = actionEntity.getChildElement('name', SOAP_NS).getText();

        return name;
    }

    public static void validateActionEntity(Dom.XmlNode actionEntity){
        String type = getActionType(actionEntity);
        String name = getActionName(actionEntity);
        switch on type {
            when 'OutboundMessage', 'KnowledgePublish', 'Task', 'FlowAction' {
                ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + ' \n The selected Workflow Rule contains one of the following unsupported actions: OutboundMessage, Task, KnowledgePublish, FlowAction. Currently the converter only works with rules that have Update Fields and/or Email Alerts. ';
            }
            when 'FieldUpdate' {
                if (isValidFieldUpdate(name) == true) {
                    ValidateWFRMetadata.validFieldUpdateNames.add(name);
                } 
            }
        }
    }

    //a workflow metadata may have actions from more than 1 rule. Extract the ones from the rule that matters
    public static List<Dom.XmlNode> getRuleActions(Dom.XMLNode rulesEntity ) {
        List<Dom.XmlNode> curActions = new List<Dom.XmlNode>();
        for(Dom.XmlNode node : rulesEntity.getChildren()) {
            if(node.getName() == 'actions') {
                curActions.add(node);
            }
        }


        return curActions;

    }

    /*     public static Boolean containsIsChangedInName(Dom.XmlNode curDecisionNode) {
            //get the text of the name element
            String curName = XmlUtils.getInternalName(curDecisionNode);
            return curName.contains('isChangedDecision') ? true : false;
           
        } */
    
    
     /*    public static Boolean containsPmetdec(Dom.XmlNode curDecisionNode) {
            String curName = XmlUtils.getInternalName(curDecisionNode);
            return curName.contains('pmetdec') ? true : false;
    
        } */

    }
    