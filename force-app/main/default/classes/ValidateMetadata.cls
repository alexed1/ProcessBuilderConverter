public with sharing class ValidateMetadata {
    
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    public static string validate(String flowMetadata) {
        String validityProblemString = '';
        Dom.Document doc = new Dom.Document();
        doc.load(flowMetadata);
        //Retrieve the root element for this document.
        Dom.XMLNode flowXML = doc.getRootElement();

        //Flow doesn't support IsChanged, IsNew, and PriorValue yet
        //IsChanged can manifest in three ways:
        // 1. a decisions element with a name like this:   <name>isChangedDecision4_myRule_3_Rating</name>
        // 2. a decisions element that reference a formula with an expression that includes:  ISCHANGED:  <expression> ISCHANGED({!myVariable_current.Industry} )</expression>
        // 3. a decisions element that has 'pmetdec', which is used to evaluate for a previously met decisions. this corresponds to the Advanced 'execute only when changes are made' checkbox in the Decisions critera
        //terminate conversion if any of these are found

        //get all decision elements, for each element, if one of these is true, then validate problem string = x
        Dom.XmlNode  pmv_TriggerType = XmlUtils.getChildProcessMetadataValueByName(flowXML,'TriggerType');
        String triggerType = XmlUtils.getProcessMetadataValue(pmv_TriggerType);
        List<Dom.XmlNode> decisionNodes = XmlUtils.getChildrenByName(flowXml, 'decisions');
        for (Dom.XMLNode curDecision : decisionNodes) {
            if (containsIsChangedInName(curDecision) && triggerType == 'onCreateOnly')
                validityProblemString = validityProblemString + 'The selected process uses IsChanged operator On Create FLow, this supported only in Update Flow\n';
            System.debug ('current validity string is: ' + validityProblemString);

        }

        List<Dom.XmlNode> processMetadataValueNodes = XmlUtils.getChildrenByName(flowXml, 'processMetadataValues');
        for (Dom.XMLNode processMetadata : processMetadataValueNodes) {
            String processMetadataName = processMetadata.getChildElement('name', SOAP_NS).getText(); 
            if (processMetadataName == 'RecursiveCountVariable') {
                validityProblemString = validityProblemString + 'The selected process uses Recursion, and Flow doesn\'t currently support that. \n';
            }
            System.debug ('current validity string is: ' + validityProblemString);
            

        }
        List<Dom.XmlNode> formulaNodes = XmlUtils.getChildrenByName(flowXml, 'formulas');
        for (Dom.XMLNode curFormula : formulaNodes) {
            Dom.XmlNode expressionNode = curFormula.getChildElement('expression', SOAP_NS);
            // if (expressionNode != null) {
            //     if (expressionNode.getText().contains('ISCHANGED')) {           
            //         validityProblemString = validityProblemString + 'The selected process uses ISCHANGED in a formula, and Flow doesn\'t currently support that. \n';
            //     }
            //     if (expressionNode.getText().contains('ISNEW')) {           
            //         validityProblemString = validityProblemString + 'The selected process uses ISNEW in a formula, and Flow doesn\'t currently support that. \n';
            //     }
            // }
        }
        List<Dom.XmlNode> waitEventsNodes = flowXML.getChildElements();
        for(Dom.XmlNode waits:waitEventsNodes){
            if(waits.getName() == 'waits'){
                Integer waitCounter = 0;
                for(Dom.XmlNode waitsEvent:waits.getChildElements()){
                    if(waitsEvent.getName() =='waitEvents'){
                        waitCounter++;
                    }
                }
            if(waitCounter>1){
                validityProblemString = validityProblemString + 'There cannot be more than one Scheduled action related to one criteria. \n';
            }
            }
        }
        return validityProblemString;
    }

    public static Boolean containsIsChangedInName(Dom.XmlNode curDecisionNode) {
        //get the text of the name element
        String curName = XmlUtils.getInternalName(curDecisionNode);
        return curName.contains('isChangedDecision') ? true : false;
       
    }


    public static Boolean containsPmetdec(Dom.XmlNode curDecisionNode) {
        String curName = XmlUtils.getInternalName(curDecisionNode);
        return curName.contains('pmetdec') ? true : false;

    }
}