public with sharing class ValidateWFRMetadata {

    
        public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

        public static String ruleName;
        public static Dom.XMLNode wfrMetadata;
        public static String validityProblemString = '';
        public static List<String> validFieldUpdateNames = new List<String>();

        

        public static string validateRule(Dom.XMLNode wfrXML, String ruleName) {

            ValidateWFRMetadata.ruleName = ruleName;
            
             
    
           

            //get the matching rules entity. The other ones won't be used
            Dom.XMLNode rulesEntity = getRulesEntity(wfrXML, ruleName);

            

            //don't currently support time triggers
            if (hasTimeTriggers(rulesEntity) == true)
            ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + 'This converter can not currently convert WorkflowRules with Time Triggers  \n';
    

            //get and validate the corresponding action entities
            List<Dom.XmlNode> actionEntities = getRuleActions(rulesEntity);
            for(Dom.XmlNode actionEntity : actionEntities) {
                validateActionEntity(actionEntity);
            }

            return ValidateWFRMetadata.validityProblemString;
/* 

            //Flow currently doesn't support Scheduled Actions as part of a record change-triggered Flow, so filter out flows with Pause element
            Dom.XmlNode waitNodes = flowXML.getChildElement('waits', SOAP_NS);
            if (waitNodes != null)
            ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + 'Triggers in Flow Builder do not currently support Scheduled Actions, and this Process Builder process has at least 1. \n';
    
    
            //Flow doesn't support IsChanged, IsNew, and PriorValue yet
            //IsChanged can manifest in three ways:
            // 1. a decisions element with a name like this:   <name>isChangedDecision4_myRule_3_Rating</name>
            // 2. a decisions element that reference a formula with an expression that includes:  ISCHANGED:  <expression> ISCHANGED({!myVariable_current.Industry} )</expression>
            // 3. a decisions element that has 'pmetdec', which is used to evaluate for a previously met decisions. this corresponds to the Advanced 'execute only when changes are made' checkbox in the Decisions critera
            //terminate conversion if any of these are found
    
            //get all decision elements, for each element, if one of these is true, then validate problem string = x
            List<Dom.XmlNode> decisionNodes = XmlUtils.getChildrenByName(flowXml, 'decisions');
            for (Dom.XMLNode curDecision : decisionNodes) {
                if (containsIsChangedInName(curDecision))
                    validityProblemString = validityProblemString + 'The selected process uses IsChanged operator, and Flow doesn\'t currently support that. \n';
                if (containsPmetdec(curDecision))
                    validityProblemString = validityProblemString + 'The selected process uses the Advanced \'execute only when changes are made\' checkbox in a decision, and Flow doesn\'t currently support that. \n';
                System.debug ('current validity string is: ' + validityProblemString);
    
            }
    
            List<Dom.XmlNode> formulaNodes = XmlUtils.getChildrenByName(flowXml, 'formulas');
            for (Dom.XMLNode curFormula : formulaNodes) {
                Dom.XmlNode expressionNode = curFormula.getChildElement('expression', SOAP_NS);
                if (expressionNode != null) {
                    if (expressionNode.getText().contains('ISCHANGED')) {           
                        validityProblemString = validityProblemString + 'The selected process uses ISCHANGED in a formula, and Flow doesn\'t currently support that. \n';
                    }
                    if (expressionNode.getText().contains('ISNEW')) {           
                        validityProblemString = validityProblemString + 'The selected process uses ISNEW in a formula, and Flow doesn\'t currently support that. \n';
                    }
                    if (expressionNode.getText().contains('PRIORVALUE')) {           
                        validityProblemString = validityProblemString + 'The selected process uses PRIORVALUE in a formula, and Flow doesn\'t currently support that. \n';
                    }
                    
                }
            }
            
                 */
    
             //   TODO: Fix This. It currently doesn\'t match
            //Flow currently doesn't support related record traversals as part of record change -triggered Flows
            //look for the pattern myVariable_current.foo.bar. if there are more than one period following myVariable_current, it's a hit
            // First, instantiate a new Pattern object "MyPattern"
            //this pattern looks for myVariable_current, followed by a period, then another word, then another period. However, it has an exception for when the following word is Owner or User because those can get autoconverted and used in Flow
            
           /*  String testpattern = '(myVariable_current\\.){1}(?!Owner.Id)(?!User.Id)\\w+\\.{1}';
            String test2 = '(myVariable_current)';
            Pattern MyPattern = Pattern.compile(test2);
    
            System.debug('flowmetadata is :' + wfrMetadata);
            // Then instantiate a new Matcher object "MyMatcher"
            Matcher MyMatcher = MyPattern.matcher(wfrMetadata);
    
            // You can use the system static method assert to verify the match
            if(MyMatcher.matches() == true) {
                System.debug('matcher matched');
                validityProblemString = validityProblemString + ' The target process has a related record reference such as $Record.CreatedBy.ManagerId. Flow that use record-change triggers don\'t support those yet.';
    
            } else {
                System.debug('matcher didnot match');
            }
    
    
    
            return validityProblemString; */
        }

    public static Dom.XmlNode getRulesEntity (Dom.XmlNode wfrXML, String ruleName) {
        Dom.XmlNode curRule = XmlUtils.getChildNodeByName(wfrXML, 'fullName',  'rules',  ruleName);
        return curRule;

    }

    public static Boolean hasTimeTriggers (Dom.XmlNode rulesEntity) {
        Boolean hasTimeTriggers = false;

        return hasTimeTriggers;

    }

    //some fieldUpdates use special types or formulas, and are not yet supported
    public static Boolean isValidFieldUpdate(String fieldUpdateName) {
        Boolean isValid = true;
        //if reevaluateOnChange entity exists and is true, reject with error
        //if operation entity is not ‘Literal’, reject with error
        

        return isValid;

    }

    public static String getActionType(Dom.XmlNode actionEntity) {

        String type;
        return type;
    }

    public static String getActionName(Dom.XmlNode actionEntity) {

        String name;
        return name;
    }

    public static void validateActionEntity(Dom.XmlNode actionEntity){
        String type = getActionType(actionEntity);
        String name = getActionName(actionEntity);
        switch on type {
            when 'OutboundMessage', 'KnowledgePublish', 'Task', 'FlowAction' {
                ValidateWFRMetadata.validityProblemString = ValidateWFRMetadata.validityProblemString + ' /n This rule contains one of the following: OutboundMessage, Task, KnowledgePublish, FlowAction. Currently the converter doesn\'t support rules that have these. ';
            }
            when else {
                if (isValidFieldUpdate(name) == true) {
                    ValidateWFRMetadata.validFieldUpdateNames.add(name);
                }
            }
        }
    }

    //a workflow metadata may have actions from more than 1 rule. Extract the ones from the rule that matters
    public static List<Dom.XmlNode> getRuleActions(Dom.XMLNode rulesEntity ) {
        List<Dom.XmlNode> curActions = new List<Dom.XmlNode>();


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
    