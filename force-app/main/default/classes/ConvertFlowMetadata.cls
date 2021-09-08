public with sharing class ConvertFlowMetadata {
 
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    @InvocableMethod
    public static List <Results> convert(List<Requests> requestList) {
        System.debug('entering invocable method ConvertFlowMetadata.convert');
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        String flowName;

        for (Requests req : requestList) {


            String flowmetadata = unpackZipfile( req.flowMetadataZipFile);

            String validityProblemString = ValidateMetadata.validate (flowmetadata);
            if(validityProblemString == '') {
                String metadataText = convertMetadata(flowmetadata, req.flowName);
                response.convertedFlowMetadata = metadataText;
            } else {
                response.errors = validityProblemString;
            }
            responseWrapper.add(response);
        }
        return responseWrapper;
    }

    public static String unpackZipfile(String metadataZipfile) {

             
        Blob zipBlob = EncodingUtil.base64Decode(metadataZipfile);
        usf.Zippex curZippex = new usf.Zippex(zipBlob);
        Set<String> fileNames = curZippex.getFileNames();

     
        List<String> filenamesList = new List<String>(fileNames);

           //currently only set up to handle a single file
        Blob fileData = curZippex.getFile(filenamesList[0]);

        return  fileData.toString();
    }

    public static String convertMetadata(String metadata, String flowName) {
        Dom.Document doc = new Dom.Document();
        doc.load(metadata);
        Dom.XMLNode flowXML = doc.getRootElement();
        Dom.XmlNode pmv_ObjectType = XmlUtils.getChildProcessMetadataValueByName(flowXML,'ObjectType');
        String contextObjectType = XmlUtils.getProcessMetadataValue(pmv_ObjectType);


        Dom.XmlNode  pmv_TriggerType = XmlUtils.getChildProcessMetadataValueByName(flowXML,'TriggerType');
        String triggerType = XmlUtils.getProcessMetadataValue(pmv_TriggerType);

        System.debug('triggerType for flow: ' + flowName +' is: ' + triggerType); 
        
        String startElementReference = removeIsChangedDecisions(flowXML);
        if(startElementReference == null) {
            startElementReference = flowXML.getChildElement('startElementReference', SOAP_NS).getText();
        }

        String newProcessType = 'AutolaunchedFlow';
        List<Dom.XmlNode> nodesToREmove = new List<Dom.XmlNode>();
        List<Dom.XmlNode> decisionNodes = XmlUtils.getChildrenByName(flowXml, 'decisions');
        for(Dom.XmlNode decision : decisionNodes) {
            String refName = getDecisionRefName(decision);
            System.debug('pmetdecRefName refname ' + refName);
            if(refName != null && refName.contains('pmetdec')) {
                Dom.XmlNode pmetdec = getDecisionByName(decisionNodes, refName);
                String pmetdecRefName = getDecisionRefName(pmetdec);
                Dom.XmlNode parent = pmetdec.getParent();
                if(parent != null) {
                    parent.removeChild(pmetdec);
                }
                setDecisionRefName(decision, pmetdecRefName);
            }        
        }
        
        List<WaitElementsWrapper> waitElWr = new List<WaitElementsWrapper>();
        List<Dom.XmlNode> waitEl = XmlUtils.getChildrenByName(flowXML, 'waits');
        for(Dom.XmlNode waitElements:waitEl){
            WaitElementsWrapper newWaiwr = new WaitElementsWrapper();
            newWaiwr.schName = waitElements.getChildElement('name', SOAP_NS).getText();
            newWaiwr.label = waitElements.getChildElement('label', SOAP_NS).getText();
            Dom.XmlNode conn = waitElements.getChildElement('waitEvents',SOAP_NS).getChildElement('connector', SOAP_NS);
            Dom.XmlNode targRef = conn.getChildElement('targetReference', SOAP_NS);
            newWaiwr.connector = targRef.getText();
            List<Dom.XmlNode> schParams = waitElements.getChildElement('waitEvents',SOAP_NS).getChildren();
            for(Dom.XmlNode nodes: schParams){
                if(nodes.getName()=='inputParameters'){
                Dom.XmlNode inputPar = nodes.getChildElement('name', SOAP_NS);
                if(inputPar.getText() =='TimeOffsetUnit'){
                    Dom.XmlNode value = nodes.getChildElement('value', SOAP_NS).getChildElement('stringValue', SOAP_NS);
                    newWaiwr.offsetUnit = value.getText();
                }
                if(inputPar.getText() =='TimeOffset'){
                    Dom.XmlNode timeOffsetValue = nodes.getChildElement('value', SOAP_NS).getChildElement('numberValue', SOAP_NS);
                    String returnValue = timeOffsetValue.getText();
                    newWaiwr.offsetNumber = String.valueOf(Integer.valueOf(returnValue));//returnValue.replaceAll('[^1-9\\s+]', '');
                    
                }
                if(inputPar.getText() =='TimeFieldColumnEnumOrId'){
                    Dom.XmlNode timeFieldColumnValue = nodes.getChildElement('value', SOAP_NS).getChildElement('stringValue', SOAP_NS);
                    newWaiwr.recordField = timeFieldColumnValue.getText();
                }
            }
            }
            waitElWr.add(newWaiwr);
        }
        
        
        //removeAssigmentReference(flowXML);
        for(WaitElementsWrapper elementName:waitElWr){
            removeWaitsElements(flowXML);
            removeWaitRefName(flowXML,elementName.schName);
        }
        checkCondition(flowXML);
        getExpression(flowXML);
        enableAutoLayout(flowXML);
        addConversionLog(flowXML);
        addConversionSource(flowXML);
        ModifyFlowMetadata.convertSubflow(flowXML);
        flowXML = ModifyFlowMetadata.changeProcessType(flowXML, newProcessType);
        flowXML = ModifyFlowMetadata.setStatus(flowXML, 'Draft' );
        flowXML = ModifyFlowMetadata.addStartElement(flowXML, contextObjectType, triggerType, startElementReference, waitElWr); 
        doc = removeAssigmentsElements(doc); 
        flowXML = doc.getRootElement();
        ModifyFlowMetadata.setTriggerType(flowXML, false);
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'ObjectType');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'ObjectVariable');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'OldObjectVariable');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'RecursiveCountVariable');
        ModifyFlowMetadata.removeExcessPMV(flowXML, 'TriggerType');
        doc = ModifyFlowMetadata.changeContextReference(doc); 
        doc = ModifyFlowMetadata.fixupRelatedReferences(doc);
        ModifyFlowMetadata.repositionElements(doc);
        doc = removeNoCriteriaDecisons(doc);
        doc = removeEmptyDecisons(doc);
        String classText = doc.toXmlString();
        System.debug('===========');
        System.debug ('following all conversion, is: ' + classText);
        //deployChangedMetadata(classText, flowName, null, 'Flow');    

        return classText;
            
    }
    public static Dom.XmlNode removeWaitsElements(Dom.XmlNode flowXML) {
        List<Dom.XmlNode> waitNodes = XmlUtils.getChildrenByName(flowXML, 'waits');
        for(Dom.XmlNode wait : waitNodes) {
            Dom.XmlNode parent = wait.getParent();
            if(parent != null){
                parent.removeChild(wait);
            }
        }
        return null;
    }

    public static String removeIsChangedDecisions(Dom.XmlNode flowXML) {
        List<Dom.XmlNode> decisionList = XmlUtils.getChildrenByName(flowXML, 'decisions');
        Map<String, Dom.XmlNode> rulesMap = new Map<String, Dom.XmlNode>();

        String referenceName;
        for(Dom.XmlNode decision : decisionList) {
            if(ValidateMetadata.containsIsChangedInName(decision)) {
                Dom.XmlNode rule = decision.getChildElement('rules', SOAP_NS);
                rulesMap.put(rule.getChildElement('name', SOAP_NS).getText(), rule);
                Dom.XmlNode parent = decision.getParent();
                referenceName = decision.getChildElement('defaultConnector', SOAP_NS).getChildElement('targetReference', SOAP_NS).getText();
                if(parent != null){
                    System.debug('bbbbbbb ' + decision);
                    parent.removeChild(decision);
                }
            }
        }

        for(Dom.XmlNode decision : decisionList) {
            if(!ValidateMetadata.containsIsChangedInName(decision)) {
                List<Dom.XmlNode> conditionList = XmlUtils.getChildrenByName(decision.getChildElement('rules', SOAP_NS), 'conditions');
                for(Dom.XmlNode condition : conditionList) {
                    Dom.XmlNode leftValueReference = condition.getChildElement('leftValueReference', SOAP_NS);
                    Dom.XmlNode rules = rulesMap.get(leftValueReference.getText());
                    if(rules != null) {
                        Dom.XmlNode conditionIsChange = XmlUtils.getChildrenByName(rules ,'conditions')[1];

                        String field = conditionIsChange.getChildElement('leftValueReference', SOAP_NS).getText();
                        Boolean rightValue = (conditionIsChange.getChildElement('operator', SOAP_NS).getText() == 'NotEqualTo');

                        leftValueReference.getParent().removeChild(leftValueReference);
                        condition.addChildElement('leftValueReference', SOAP_NS, null).addTextNode(field.replace('myVariable_old', '$Record'));
                        condition.removeChild(condition.getChildElement('operator', SOAP_NS));
                        condition.addChildElement('operator', SOAP_NS, null).addTextNode('IsChanged');
                        condition.removeChild(condition.getChildElement('rightValue', SOAP_NS));
                        condition.addChildElement('rightValue', SOAP_NS, null).addChildElement('booleanValue', SOAP_NS, null).addTextNode(String.valueOf(rightValue));
                    }

                    
                }
            }
        }   
        return referenceName;
    }

    public static Dom.XmlNode removeWaitRefName(Dom.XMLNode flowXML, String name) {
        List<Dom.XmlNode> wait = flowXML.getChildren();
        for(Dom.XmlNode waitRef:wait){
            if(waitRef.getName()=='decisions'){
                Dom.XmlNode rules = waitRef.getChildElement('rules', SOAP_NS);
                Dom.XmlNode desConnector = rules.getChildElement('connector', SOAP_NS);
                if(desConnector != null){
                Dom.XmlNode targetRef = desConnector.getChildElement('targetReference', SOAP_NS);
                if(targetRef.getText() == name){
                    desConnector.getParent().removeChild(desConnector);
                } else {
                    Dom.XmlNode defaultConnector = waitRef.getChildElement('defaultConnector', SOAP_NS);
                    if(defaultConnector != null) {
                        String referenceName = defaultConnector.getChildElement('targetReference', SOAP_NS).getText();
                        if(referenceName == name) {
                            defaultConnector.getParent().removeChild(defaultConnector);
                        }
                    }
                }
            }
            }
        
            else{
                Dom.XmlNode connector = waitRef.getChildElement('connector', SOAP_NS);
                if(connector != null){
                    Dom.XmlNode targetReference = connector.getChildElement('targetReference', SOAP_NS);
                    String refName = targetReference.getText();
                    if(refName == name) {    
                        connector.getParent().removeChild(connector);
                    }
                }
            }
        }
        return null;
    }

    public static Dom.XmlNode checkCondition(Dom.XMLNode flowXML){
        List<Dom.XmlNode> allElements = flowXML.getChildren();
        Map<String,Dom.XmlNode> conditionElements = new Map<String,Dom.XmlNode>();
        for(Dom.XmlNode conditions:allElements){
            if(conditions.getName()=='decisions' && conditions != null){
                String name = conditions.getChildElement('name', SOAP_NS).getText();
                if(name.contains('myPreWaitDecision')){
                    conditionElements.put(name,conditions);
                }
            }
        }
        for(Dom.XmlNode conditions:allElements){
            if(conditions.getName()=='decisions'){    
            Dom.XmlNode name = conditions.getChildElement('name', SOAP_NS);
                if(name.getText().contains('myPostWaitDecision')){
                    String nameOfWair = name.getText().replace('myPostWaitDecision_myWaitEvent_','');
                    String nameForCheckCond = nameOfWair.substringBefore('_event_');
                    Dom.XmlNode checkCond = conditions.getChildElement('rules', SOAP_NS);
                    Dom.XmlNode condit = checkCond.getChildElement('conditions', SOAP_NS);
                    if(condit != null){

                        condit.getParent().removeChild(condit);
                    }
                    for(Dom.XmlNode newEl:conditionElements.values()){
                        if(newEl.getChildElement('name', SOAP_NS).getText().contains(nameForCheckCond)){
                        List<Dom.XmlNode> elem = newEl.getChildElement('rules', SOAP_NS).getChildren();
                        for(Dom.XmlNode e:elem){
                            if(e.getName()=='conditions'){
                            Dom.XmlNode nodes = e.getChildElement('rightValue', SOAP_NS);
                            system.debug('nodes '+nodes); 
                            Dom.XmlNode con = checkCond.addChildElement('conditions', null, null);
                            con.addChildElement('leftValueReference', null, null).addTextNode(e.getChildElement('leftValueReference', SOAP_NS).getText());
                            con.addChildElement('operator', null, null).addTextNode(e.getChildElement('operator', SOAP_NS).getText());
                            for(Dom.XmlNode value:nodes.getChildElements()){
                                con.addChildElement('rightValue', null, null).addChildElement(value.getName(), null, null).addTextNode(value.getText());
                            }
                        }
                       }
                    }
                    }
                }
            }
        }
        return null; 
    }

    public static Map<String,String> getExpression(Dom.XMLNode flowXML) {
        List<Dom.XmlNode> listElem = flowXML.getChildren();
        Map<String,String> nameAndFormulas = new Map<String,String>();
        List<dom.XmlNode> listFormulas = new List<dom.XmlNode>();
        for(Dom.XmlNode formulaName: listElem){ 
            if(formulaName.getName() =='formulas'){ 
            String name = formulaName.getChildElement('name', SOAP_NS).getText();
            if(name.contains('formula')){listFormulas.add(formulaName);}
            String expression = formulaName.getChildElement('expression', SOAP_NS).getText();
            String removePriorValue = expression.replace('PRIORVALUE({!myVariable_current', '{! $Record__Prior');
            String expAfterFormating = removePriorValue.replace('})','}');
            nameAndFormulas.put(name,expAfterFormating);
            dom.XmlNode n = flowXML.getChildElement('formulas', SOAP_NS);
            dom.XmlNode expr = formulaName.getChildElement('expression', SOAP_NS);
            expr.getParent().removeChild(expr);
        }
    }
        for(String values:nameAndFormulas.keySet()){
            for(dom.XmlNode formNodes:listFormulas){
                if(formNodes!=null && values==formNodes.getChildElement('name',SOAP_NS).getText()){
                    formNodes.addChildElement('expression', SOAP_NS, null).addTextNode(nameAndFormulas.get(values));
                break;    
                }
            }
        }
        return null;
    }

    public static Dom.XmlNode getDecisionByName(List<Dom.XmlNode> decisionList, String name) {
        for(Dom.XmlNode item : decisionList){
            if(XmlUtils.getInternalName(item) == name) {
                return item;
            }
        }
        return null;
    }

    public static String getDecisionRefName(Dom.XmlNode decision) {
        Dom.XmlNode rule = decision.getChildElement('rules', SOAP_NS);
        if(rule != null) {
            Dom.XmlNode connector = rule.getChildElement('connector', SOAP_NS);
            if(connector != null){
                Dom.XmlNode targetReference = connector.getChildElement('targetReference', SOAP_NS);
                String refName = targetReference.getText();
                if(refName != null) {
                    return refName;
                }
            }
        }
        return null;
    }

    public static Boolean setDecisionRefName(Dom.XmlNode decision, String refName) {
        Dom.XmlNode rule = decision.getChildElement('rules', SOAP_NS);
        if(rule != null) {
            Dom.XmlNode connector = rule.getChildElement('connector', SOAP_NS);
            Dom.XmlNode targetReference = connector.getChildElement('targetReference', SOAP_NS);
            connector.removeChild(targetReference);
            targetReference = connector.addChildElement('targetReference', SOAP_NS, null);
            targetReference.addTextNode(refName);
            Dom.XmlNode doesRequireRecordChangedToMeetCriteria = rule.addChildElement('doesRequireRecordChangedToMeetCriteria', SOAP_NS, null);
            doesRequireRecordChangedToMeetCriteria.addTextNode('true');
        }
        return null;
    }

    public static Dom.XmlNode enableAutoLayout(Dom.XmlNode flowXML) {
            Dom.XmlNode processMetadata = flowXML.addChildElement('processMetadataValues', SOAP_NS, null);
            if(processMetadata != null){
            processMetadata.addChildElement('name', SOAP_NS, null).addTextNode('CanvasMode');
            Dom.XmlNode value = processMetadata.addChildElement('value', SOAP_NS, null);
            value.addChildElement('stringValue', SOAP_NS, null).addTextNode('AUTO_LAYOUT_CANVAS');
            }
        return null;
    }

    public static Dom.Document removeAssigmentsElements(Dom.Document doc) {
        Dom.XmlNode flowXML = doc.getRootElement();
        List<Dom.XmlNode> assignmentsNode = XmlUtils.getChildrenByName(flowXML, 'assignments');
        Map<String, String> referenceMap = new Map<String, String>();


        for(Dom.XmlNode assignment : assignmentsNode) {
            Dom.XmlNode parent = assignment.getParent();
            String assignmentName = assignment.getChildElement('name', SOAP_NS).getText();
            Dom.XmlNode referenceNameXML = assignment.getChildElement('connector', SOAP_NS);
            String referenceName = '';
            if(referenceNameXML != null) {
                referenceName = referenceNameXML.getChildElement('targetReference', SOAP_NS).getText();
            }

            if(parent != null){
                referenceMap.put(assignmentName, referenceName);
                parent.removeChild(assignment);
            }
        }
        System.debug('refMap ' + referenceMap);

        List<String> keySet = new List<String>(referenceMap.keySet());
        for(Integer i = 0; i < referenceMap.size(); i++) {
            if(referenceMap.get(referenceMap.get(keySet[i])) != null) {
                referenceMap.put(keySet[i],referenceMap.get(referenceMap.get(keySet[i])));
                i--;
            }
        }

        String xmlText = doc.toXmlString();
        for(String key : referenceMap.keySet()) {
            System.debug('decisions - ' + key + ' ' + referenceMap.get(key));
            if(String.isEmpty(referenceMap.get(key))) {
                xmlText = xmlText.replaceAll('\n', '');
                xmlText = xmlText.replaceAll('<connector>(\\s*<targetReference>' + key + '</targetReference>\\s*)</connector>', referenceMap.get(key));
                xmlText = xmlText.replaceAll('<defaultConnector>(\\s*<targetReference>' + key + '</targetReference>\\s*)</defaultConnector>', referenceMap.get(key));
            } else {
                xmlText = xmlText.replace(key, referenceMap.get(key));
            }
        }
        System.debug('xmlText ' + xmlText);

        doc =new Dom.Document();
        doc.load(xmlText);
        return doc;
    }

    // public static Dom.XmlNode removeAssigmentReference(Dom.XmlNode flowXML){
    //     List<Dom.XmlNode> listElements = flowXML.getChildren();
    //     for(Dom.XmlNode assigmentRef:listElements){
    //         if(assigmentRef.getName() == 'decisions'){
    //             Dom.XmlNode assRefToDec = assigmentRef.getChildElement('defaultConnector', SOAP_NS);
    //             if(assRefToDec != null){
    //                 String targRefName = assRefToDec.getChildElement('targetReference', SOAP_NS).getText();
    //                 if(targRefName.contains('Assignment')){
    //                     assRefToDec.getParent().removeChild(assRefToDec);
    //                 }
    //             }
    //         }
    //         if(assigmentRef.getName() == 'actionCalls'){
    //             Dom.XmlNode actionCallsRef = assigmentRef.getChildElement('connector', SOAP_NS);
    //             if(actionCallsRef != null){
    //                 String targRefName = actionCallsRef.getChildElement('targetReference', SOAP_NS).getText();
    //                 if(targRefName.contains('Assignment')){
    //                     actionCallsRef.getParent().removeChild(actionCallsRef);
    //                 }
    //             }
    //         }
    //         if(assigmentRef.getName() == 'recordUpdates'){
    //             Dom.XmlNode refForUpdateRec = assigmentRef.getChildElement('connector', SOAP_NS);
    //             if(refForUpdateRec != null){
    //                 String targRefName = refForUpdateRec.getChildElement('targetReference', SOAP_NS).getText();
    //                 if(targRefName.contains('Assignment')){
    //                     refForUpdateRec.getParent().removeChild(refForUpdateRec);
    //                 }
    //             }
    //         }
    //         if(assigmentRef.getName() == 'recordCreates'){
    //             Dom.XmlNode refToRecordCreate = assigmentRef.getChildElement('connector', SOAP_NS);
    //             if(refToRecordCreate != null){
    //                 String targRefName = refToRecordCreate.getChildElement('targetReference', SOAP_NS).getText();
    //                 if(targRefName.contains('Assignment')){
    //                     refToRecordCreate.getParent().removeChild(refToRecordCreate);
    //                 }
    //             }
    //         }

    //     }
    //     return null;
    // }

    public static Dom.XmlNode addConversionLog(Dom.XmlNode flowXML){
        Dom.XmlNode processMetadata = flowXML.addChildElement('processMetadataValues', SOAP_NS, null);
            if(processMetadata != null){
            processMetadata.addChildElement('name', SOAP_NS, null).addTextNode('ConversionLog');
            Dom.XmlNode value = processMetadata.addChildElement('value', SOAP_NS, null);
            value.addChildElement('stringValue', SOAP_NS, null).addTextNode('ConvertedByConvertToFlow');
            }
        return null;
    }

    public static Dom.XmlNode addConversionSource(Dom.XmlNode flowXML){
        Dom.XmlNode processMetadata = flowXML.addChildElement('processMetadataValues', SOAP_NS, null);
            if(processMetadata != null){
            processMetadata.addChildElement('name', SOAP_NS, null).addTextNode('ConversionSource');
            Dom.XmlNode value = processMetadata.addChildElement('value', SOAP_NS, null);
            value.addChildElement('stringValue', SOAP_NS, null).addTextNode('ProcessBuilder');
            }
        return null;
    }

    public static Dom.Document removeNoCriteriaDecisons(Dom.Document doc) {
        Dom.XmlNode flowXML = doc.getRootElement();
        List<Dom.XmlNode> decisionList = XmlUtils.getChildrenByName(flowXML, 'decisions');
        List<Dom.XmlNode> decisionToDeleteList = new List<Dom.XmlNode>();
        List<Dom.XmlNode> formulaList = XmlUtils.getChildrenByName(flowXML, 'formulas');
        Map<string, String> referenceMap = new Map<String, String>();
        for(Dom.XmlNode decision : decisionList) {
            List<Dom.XmlNode> ruleList  = XmlUtils.getChildrenByName(decision, 'rules');
            String decisionName = decision.getChildElement('name', SOAP_NS).getText();
            if(ruleList.size() == 1) {
                List<Dom.XmlNode> conditionList  = XmlUtils.getChildrenByName(ruleList[0], 'conditions');
                if(conditionList.size() == 1) {
                    for(Dom.XmlNode formula : formulaList) {
                        String formulaText = formula.getChildElement('name', SOAP_NS).getText();
                        String conditionFomulaRef = conditionList[0].getChildElement('leftValueReference',SOAP_NS).getText();
                        String formulaExpression = formula.getChildElement('expression', SOAP_NS).getText();
                        if(formulaText == conditionFomulaRef && formulaExpression == 'true') {
                            
                            Dom.XmlNode connector = ruleList[0].getChildElement('connector', SOAP_NS);
                            String reference = '';
                            if(connector != null) {
                                reference = connector.getChildElement('targetReference', SOAP_NS).getText();
                            } 
                            decisionToDeleteList.add(decision);
                            referenceMap.put(decisionName, reference);
                            break;
                        }
                    }
                }
            }
        }
        
        
        for(Dom.XmlNode decision : decisionToDeleteList) {
            decision.getParent().removeChild(decision);
        }
        List<String> keySet = new List<String>(referenceMap.keySet());
        for(Integer i = 0; i < referenceMap.size(); i++) {
            if(referenceMap.get(referenceMap.get(keySet[i])) != null) {
                referenceMap.put(keySet[i],referenceMap.get(referenceMap.get(keySet[i])));
                i--;
            }
        }
        String xmlText = doc.toXmlString();
        for(String key : referenceMap.keySet()) {
            System.debug('decisions - ' + key + ' ' + referenceMap.get(key));
            if(String.isEmpty(referenceMap.get(key))) {
                xmlText = xmlText.replaceAll('\n', '');
                xmlText = xmlText.replaceAll('<connector>(\\s*<targetReference>' + key + '</targetReference>\\s*)</connector>', referenceMap.get(key));
                xmlText = xmlText.replaceAll('<defaultConnector>(\\s*<targetReference>' + key + '</targetReference>\\s*)</defaultConnector>', referenceMap.get(key));
                
            } else {
                xmlText = xmlText.replace(key, referenceMap.get(key));
            }
        }

        doc =new Dom.Document();
        doc.load(xmlText);
        return doc;
    }

    public static Dom.Document removeEmptyDecisons(Dom.Document doc) {
        Dom.XmlNode flowXML = doc.getRootElement();
        List<Dom.XmlNode> decisionList = XmlUtils.getChildrenByName(flowXML, 'decisions');
        List<Dom.XmlNode> decisionToDeleteList = new List<Dom.XmlNode>();
        Map<string, String> referenceMap = new Map<String, String>();
        for(Dom.XmlNode decision : decisionList) {
            List<Dom.XmlNode> ruleList  = XmlUtils.getChildrenByName(decision, 'rules');
            String referenceName = '';
            Dom.XmlNode defaultConnector = decision.getChildElement('defaultConnector', SOAP_NS);
            if(defaultConnector != null) {
                referenceName = defaultConnector.getChildElement('targetReference', SOAP_NS).getText();
            }
            String decisionName = decision.getChildElement('name', SOAP_NS).getText();
            System.debug('aaaaaaaaaaa ' + decisionName + referenceName);
            if(ruleList.size() == 1) {
                Dom.XmlNode connector = ruleList[0].getChildElement('connector', SOAP_NS);
                if(connector == null || connector.getChildElement('targetReference', SOAP_NS).getText() == referenceName) {
                    referenceMap.put(decisionName, referenceName);
                    System.debug('ccccc ' + decisionName);
                    decisionToDeleteList.add(decision);
                }
    
            }
        }        

        for(Dom.XmlNode decision : decisionToDeleteList) {
            decision.getParent().removeChild(decision);
        }
        List<String> keySet = new List<String>(referenceMap.keySet());
        for(Integer i = 0; i < referenceMap.size(); i++) {
            if(referenceMap.get(referenceMap.get(keySet[i])) != null) {
                referenceMap.put(keySet[i],referenceMap.get(referenceMap.get(keySet[i])));
                i--;
            }
        }
        String xmlText = doc.toXmlString();
        for(String key : referenceMap.keySet()) {

            if(String.isEmpty(referenceMap.get(key))) {
                xmlText = xmlText.replaceAll('\n', '');
                xmlText = xmlText.replaceAll('<connector>(\\s*<targetReference>' + key + '</targetReference>\\s*)</connector>', referenceMap.get(key));
                xmlText = xmlText.replaceAll('<defaultConnector>(\\s*<targetReference>' + key + '</targetReference>\\s*)</defaultConnector>', referenceMap.get(key));
            } else {
                xmlText = xmlText.replace(key, referenceMap.get(key));
            }
        }

        doc =new Dom.Document();
        doc.load(xmlText);
        return doc;
    }


 

    public static void deployChangedMetadata(String classText, String className, String testLevel, String objectType) {

        //DeployMetadata.deploy(classText, className, testLevel, objectType);


    }

 
    

    public class Requests {
       
        @InvocableVariable 
        public String flowName;

        @InvocableVariable 
        public String flowMetadataZipFile;

       

      

    }

    public class Results {

        @InvocableVariable
        public String errors;

       
        @InvocableVariable
        public String convertedFlowMetadata;

    }

    public class WaitElementsWrapper{
        public String schName;
        public String label;
        public String connector;
        public String offsetNumber;
        public String offsetUnit;
        public String recordField; 
    }

    public class PBConvertException extends Exception{}
}