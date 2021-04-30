public with sharing class ConvertWFRMetadata {
 
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    final static Map<String, string> WFR_TO_FLOW_OPERATOR_MAP = new Map<String, String>{
        'notEqual' => 'NotEqualTo',
        'equals' =>'EqualTo',
        'startsWith' =>'StartsWith',
        'contains' =>'Contains',
        'notContain' =>'Contains',
        'greaterThan' =>'GreaterThan',
        'lessThan' =>'LessThan',
        'lessOrEqual' =>'LessThanOrEqualTo',
        'greaterOrEqual' =>'GreaterThanOrEqualTo'

    };

    @InvocableMethod
    public static List <Results> convert(List<Requests> requestList) {
        //try {System.debug('entering invocable method ConvertWFRMetadata.convert');
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();
        //String flowName;

        for (Requests req : requestList) {

            String wfrmetadata = unpackZipfile( req.wfrMetadataZipFile);



            Dom.Document doc = new Dom.Document();
            doc.load(wfrmetadata);
            Dom.XMLNode wfrXML = doc.getRootElement();

            String validityProblemString = ValidateWFRMetadata.validateRule (wfrXML, req.wfrName);
            //String validityProblemString = '';
            System.debug('validtyProblemString is: ' + validityProblemString);
            if(validityProblemString == '') {
                response.convertedFlowMetadata = convertMetadata(wfrXML, req.wfrName);
            } else {
                response.errors = validityProblemString;
            } 
            //response.convertedFlowMetadata = wfrmetadata;
            responseWrapper.add(response);
        }
        return responseWrapper;
    }

    public static String unpackZipfile(String metadataZipfile) {

             
        Blob zipBlob = EncodingUtil.base64Decode(metadataZipfile);
        Zippex curZippex = new Zippex(zipBlob);
        Set<String> fileNames = curZippex.getFileNames();
        System.debug('filenames are: ' + fileNames);
     
        List<String> filenamesList = new List<String>(fileNames);

           //currently only set up to handle a single file
        Blob fileData = curZippex.getFile(filenamesList[0]);
        System.debug ('filename: ' + filenamesList[0]);
        return  fileData.toString();
    }

    public static String convertMetadata(Dom.XmlNode wfrXML, String wfrName) {

        String objectName = wfrName.split('\\.')[0];
        String boilerplate =  '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
        '<label>' + wfrName.replace('\\.', ' ') +'</label>' +
            '<apiVersion>51.0</apiVersion>' + 
            '<start>'+
                '<locationX>40</locationX>'+
                '<locationY>40</locationY>'+
               '<connector>'+
                  '<targetReference>MyDecision</targetReference>'+
            ' </connector>'+
                '<object>'+  objectName + '</object>'+
                //'<recordTriggerType>Create</recordTriggerType>'+
                '<triggerType>RecordAfterSave</triggerType>'+
            '</start>'+
            //'<status>Active</status>' +
        '</Flow>';
        String ruleName = wfrName.split('\\.')[1];
        Dom.Document doc = new Dom.Document();
        doc.load(boilerplate);
        Dom.XMLNode flowXML = doc.getRootElement();
        Dom.XmlNode wfrRule = ValidateWFRMetadata.getRulesEntity(wfrXML, ruleName);
        //add trigger type
        Dom.XmlNode startElement = flowXML.getChildElement('start', SOAP_NS);
        String triggerType = wfrRule.getChildElement('triggerType', SOAP_NS).getText();
        String flowTriggerType = 'Create';
        Boolean doesRequireRecordChangedToMeetCriteria = false;
        if(triggerType == 'onCreateOnly') {
            //onCreateOrTriggeringUpdate
            flowTriggerType ='Create';
           
        } else if(triggerType == 'onAllChanges') {
            flowTriggerType ='CreateAndUpdate';
        } else if(triggerType == 'onCreateOrTriggeringUpdate') {
            flowTriggerType ='CreateAndUpdate';
            doesRequireRecordChangedToMeetCriteria = true;
            //startElement.addChildElement('doesRequireRecordChangedToMeetCriteria', SOAP_NS, null).addTextNode('true');
        }
        startElement.addChildElement('recordTriggerType', SOAP_NS, null).addTextNode(
            flowTriggerType
        );
        Dom.XmlNode decision = createDecision(flowXML, wfrRule, objectName, doesRequireRecordChangedToMeetCriteria);

        
        
        //wrfRule.getChildElement(name, namespace);
        List<Dom.XmlNode> actionList = new List<Dom.XmlNode>();
        List<Dom.XmlNode> ruleActionList = ValidateWFRMetadata.getRuleActions(wfrRule);
        Integer alertCount = 1;
        for(Dom.XmlNode action : ruleActionList) {
            String actionType = ValidateWFRMetadata.getActionType(action);
            String actionName = ValidateWFRMetadata.getActionName(action);
            if(actionType == 'FieldUpdate') {
                
                Dom.XmlNode actionEntity = getAction(wfrXML,actionName);
                Dom.XmlNode convertedFlowAction = convertFieldUpdateAction(actionEntity, flowXML, objectName);
                if(convertedFlowAction != null) {
                    actionList.add(convertedFlowAction);
                }

            } else if(actionType == 'Alert') {

                Dom.XmlNode actionEntity = getAction(wfrXML, actionName);
                Dom.XmlNode convertedAlert = generateEmailAlert(actionEntity, flowXML, objectName, 'alert' + alertCount);
                alertCount++;
                if(convertedAlert != null) {
                    actionList.add(convertedAlert);
                }

            }

            
            

            //ModifyFlowMetadata.repositionElements(doc);
        }

        if(actionList.size() > 0) {
            Integer positionY = 500;
            Dom.XmlNode firstAction = actionList[0];
            
            decision.getChildElement('rules', SOAP_NS).addChildElement('connector', SOAP_NS, null)
                .addChildElement('targetReference', SOAP_NS, null)
                    .addTextNode(firstAction.getChildElement('name', SOAP_NS).getText());
                
            firstAction.addChildElement('locationX', SOAP_NS, null).addTextNode(String.valueOf(150));
            firstAction.addChildElement('locationY', SOAP_NS, null).addTextNode(String.valueOf(positionY));
            positionY += 300;
            if(actionList.size() > 1) {
                for(Integer i = 0; i < actionList.size() - 1; i++) {
                    actionList[i].addChildElement('connector', SOAP_NS, null)
                        .addChildElement('targetReference', SOAP_NS, null)
                            .addTextNode(actionList[i+1].getChildElement('name', SOAP_NS).getText());
                    actionList[i+1].addChildElement('locationX', SOAP_NS, null).addTextNode(String.valueOf(150));
                    actionList[i+1].addChildElement('locationY', SOAP_NS, null).addTextNode(String.valueOf(positionY));
                    positionY += 100;
                }
            }
        }
    

       

        String classText = doc.toXmlString();
        System.debug('===========');
        System.debug ('following all conversion, is: ' + classText);
        //deployChangedMetadata(classText, flowName, null, 'Flow');         
        return classText;
            
    }
 

    public static void deployChangedMetadata(String classText, String className, String testLevel, String objectType) {

        DeployMetadata.deploy(classText, className, testLevel, objectType);

    }
    public static Dom.XmlNode getAction(Dom.XmlNode wfrXML,String actionName) {

        for(Dom.XmlNode node : wfrXML.getChildren()) {
            
            if(node.getChildElement('fullName', SOAP_NS)!= null && node.getChildElement('fullName', SOAP_NS).getText() == actionName) {
               return node;
            }
            
        }

        return null;
    }
    public static Dom.XmlNode convertFieldUpdateAction(Dom.XmlNode actionEntity, Dom.XmlNode flowXML, String objectName) {
        Dom.XmlNode  recordUpdate = flowXML.addChildElement('recordUpdates', SOAP_NS, null);
        String actionName = actionEntity.getChildElement('fullName', SOAP_NS).getText();
        String actionLabel = actionEntity.getChildElement('name', SOAP_NS).getText();
        recordUpdate.addChildElement('name', SOAP_NS, null).addTextNode(actionName);
        recordUpdate.addChildElement('label', SOAP_NS, null).addTextNode(actionLabel);
        recordUpdate.addChildElement('object', SOAP_NS, null).addTextNode(objectName);
        recordUpdate.addChildElement('filterLogic', SOAP_NS, null).addTextNode('and');


        Dom.XmlNode filter =  recordUpdate.addChildElement('filters', SOAP_NS, null);
        filter.addChildElement('field', SOAP_NS, null).addTextNode('Id');
        filter.addChildElement('operator', SOAP_NS, null).addTextNode('EqualTo');
        filter.addChildElement('value', SOAP_NS, null).addChildElement('elementReference', SOAP_NS, null).addTextNode('$Record.Id');
        
        String field = actionEntity.getChildElement('field', SOAP_NS).getText();
        Dom.XmlNode inputAssignments =  recordUpdate.addChildElement('inputAssignments', SOAP_NS, null);
        inputAssignments.addChildElement('field', SOAP_NS, null).addTextNode(field);
        String operation = actionEntity.getChildElement('operation', SOAP_NS).getText();
        if(operation != 'Null') {
            Dom.XmlNode valueXML = actionEntity.getChildElement('literalValue', SOAP_NS);
            if(valueXML != null) {
                inputAssignments.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(valueXML.getText());
            }
        }

        return recordUpdate;
    }

    public static Dom.XmlNode generateEmailAlert(Dom.XmlNode actionEntity, Dom.XmlNode flowXML, String objectName, String alertName) {
        Dom.XmlNode  emailAlert = flowXML.addChildElement('actionCalls', SOAP_NS, null);
        Dom.XmlNode  processMetadataValues = emailAlert.addChildElement('processMetadataValues', SOAP_NS, null);
        String emailAlertName = actionEntity.getChildElement('fullName', SOAP_NS).getText();
        processMetadataValues.addChildElement('name', SOAP_NS, null).addTextNode('emailAlertSelection');
        processMetadataValues.addChildElement('value', SOAP_NS, null)
        .addChildElement('stringValue', SOAP_NS, null)
        .addTextNode(emailAlertName);
        emailAlert.addChildElement('name', SOAP_NS, null).addTextNode(alertName);
        emailAlert.addChildElement('label', SOAP_NS, null).addTextNode(alertName);

        emailAlert.addChildElement('actionName', SOAP_NS, null).addTextNode(objectName + '.' + emailAlertName);
        emailAlert.addChildElement('actionType', SOAP_NS, null).addTextNode('emailAlert');
        emailAlert.addChildElement('flowTransactionModel', SOAP_NS, null).addTextNode('CurrentTransaction');
        Dom.XmlNode  inputParameters = emailAlert.addChildElement('inputParameters', SOAP_NS, null);
        inputParameters.addChildElement('name', SOAP_NS, null).addTextNode('SObjectRowId');
        inputParameters.addChildElement('value', SOAP_NS, null).addChildElement('elementReference', SOAP_NS, null).addTextNode('$Record.Id');




        return emailAlert;
    }

    public static Dom.XmlNode createDecision(Dom.XmlNode flowXML, Dom.XmlNode wfrRule, String objectName, Boolean doesRequireRecordChangedToMeetCriteria) {
        Dom.XmlNode decision = flowXML.addChildElement('decisions', SOAP_NS, null);
        decision.addChildElement('name', SOAP_NS, null).addTextNode('MyDecision');
        decision.addChildElement('label', SOAP_NS, null).addTextNode('MyDecision');
        decision.addChildElement('locationX', SOAP_NS, null).addTextNode(String.valueOf(150));
        decision.addChildElement('locationY', SOAP_NS, null).addTextNode(String.valueOf(300));

        decision.addChildElement('defaultConnectorLabel', SOAP_NS, null).addTextNode('default');
        Dom.XmlNode rules = decision.addChildElement('rules', SOAP_NS, null);
        rules.addChildElement('name', SOAP_NS, null).addTextNode('rules_1');
        rules.addChildElement('label', SOAP_NS, null).addTextNode('rules_1');
        if(doesRequireRecordChangedToMeetCriteria) {
            rules.addChildElement('doesRequireRecordChangedToMeetCriteria', SOAP_NS, null).addTextNode('true');
        }
        //<booleanFilter>1 AND 2 AND 3 AND 4 AND 5 AND 6 AND 7 AND 8 AND 9</booleanFilter>
        Dom.XmlNode booleanFilter = wfrRule.getChildElement('booleanFilter', SOAP_NS);
        if(booleanFilter != null) {
            rules.addChildElement('conditionLogic', SOAP_NS, null).addTextNode(booleanFilter.getText());
        } else {
            rules.addChildElement('conditionLogic', SOAP_NS, null).addTextNode('and');
        }
        for(Dom.XmlNode criteriaItem : wfrRule.getChildren()) {
            if(criteriaItem.getName() == 'criteriaItems') {
                String field = criteriaItem.getChildElement('field', SOAP_NS).getText();
                String operator = criteriaItem.getChildElement('operation', SOAP_NS).getText();
                Dom.XmlNode valueXML = criteriaItem.getChildElement('value', SOAP_NS);
                String value = valueXML != null ? valueXML.getText() : '';
                Dom.XmlNode conditions = rules.addChildElement('conditions', SOAP_NS, null);

                conditions.addChildElement('operator', SOAP_NS, null).addTextNode(WFR_TO_FLOW_OPERATOR_MAP.get(operator));
                List<String> splitedField = field.split('\\.');
                if(splitedField[0] == 'User') {
                    field = '$User';
                } else {
                    field = '$Record';
                }
                Integer startLoop = (splitedField[0] == 'User' || splitedField[0] == objectName) ? 1 : 0;
                if(splitedField.size() >1) {
                    for(Integer i = startLoop; i < splitedField.size(); i++) {
                        field += '.' + splitedField[i]; 
                    }
                }
                
                conditions.addChildElement('leftValueReference', SOAP_NS, null).addTextNode(field);

                conditions.addChildElement('rightValue', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(value);

            }
        }

        return decision;
    }

 
    

    public class Requests {
       
        @InvocableVariable 
        public String wfrName;

        @InvocableVariable 
        public String wfrMetadataZipFile;

       

      

    }

    public class Results {

        @InvocableVariable
        public String errors;

       
        @InvocableVariable
        public String convertedFlowMetadata;

    }

    public class WFRConvertException extends Exception{}
}