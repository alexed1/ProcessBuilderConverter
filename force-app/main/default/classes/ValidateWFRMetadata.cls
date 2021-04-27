public with sharing class ValidateWFRMetadata {

    
        public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

        public static String ruleName;
        public static Dom.XMLNode wfrMetadata;
        public static String validityProblemString = '';
        public static List<String> validFieldUpdateNames = new List<String>();

        

        public static string validateRule(Dom.XMLNode wfrXML, String ruleName) {

            ValidateWFRMetadata.ruleName = ruleName;
            ValidateWFRMetadata.wfrMetadata = wfrXML;
            //Retrieve the root element for this document.               

            //get the matching rules entity. The other ones won't be used
            Dom.XMLNode rulesEntity = getRulesEntity(wfrXML, ruleName.split('\\.')[1]);

            

            //don't currently support time triggers
            if (hasTimeTriggers(rulesEntity) == true)
            ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + 'This converter can not currently convert WorkflowRules with Time Triggers  \n';
    

            //get and validate the corresponding action entities
            List<Dom.XmlNode> actionEntities = getRuleActions(rulesEntity);
            System.debug('actionEntities'  + actionEntities.size() + actionEntities);
            for(Dom.XmlNode actionEntity : actionEntities) {
                validateActionEntity(actionEntity);
            }

            return ValidateWFRMetadata.validityProblemString;
        }

    public static Dom.XmlNode getRulesEntity (Dom.XmlNode wfrXML, String ruleName) {
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
            if(node.getName() == 'fieldUpdates') {
                if(
                    node.getChildElement('operation', SOAP_NS).getText() != 'Literal' 
                    ||
                    node.getChildElement('reevaluateOnChange', SOAP_NS).getText() != 'true'
                    ){
                    isValid = false;
                }
                
            }
        }
        //if reevaluateOnChange entity exists and is true, reject with error
        //if operation entity is not ‘Literal’, reject with error
        

        return isValid;

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
                ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + ' \n This rule contains one of the following: OutboundMessage, Task, KnowledgePublish, FlowAction. Currently the converter doesn\'t support rules that have these. ';
            }
            when else {
                if (isValidFieldUpdate(name) == true) {
                    ValidateWFRMetadata.validFieldUpdateNames.add(name);
                } else {
                    ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + ' \n This rule has action with reevaluateOnChange = true or with action no Literal. ';
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
    