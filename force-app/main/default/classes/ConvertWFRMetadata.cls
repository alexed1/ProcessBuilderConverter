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

    final static Map<String, string> FORMULA_TYPE_MAP = new Map<String, String>{
        'BOOLEAN'  => 'Boolean',
        'CURRENCY' =>'Currency',
        'DATE' =>'Date',
        'DATETIME' =>'DateTime',
        'DOUBLE' =>'Number',
        'INTEGER' =>'Number',
        'LONG' =>'Number',
        'PERCENT' =>'Number'
    };

    static List<DescribeFieldResult> sObjectFieldList;
    static Map<String, String> userIdByUsernameMap = new Map<String,String>();
    static Map<String, String> roleIdByNameMap = new Map<String,String>();

    @InvocableMethod
    public static List <Results> convert(List<Requests> requestList) {
        Results response = new Results();
        List<Results> responseWrapper = new List<Results>();

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
        usf.Zippex curZippex = new usf.Zippex(zipBlob);
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
                '<object>'+  objectName + '</object>'+
                //'<recordTriggerType>Create</recordTriggerType>'+
                '<triggerType>RecordAfterSave</triggerType>'+
            '</start>'+
            //'<status>Active</status>' +
        '</Flow>';

        userIdByUsernameMap = getUserIdByUsernameMap();
        roleIdByNameMap = getRoleIdByNameMap();

        ConvertWFRMetadata.sObjectFieldList = getFields(objectName);
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
        }
        startElement.addChildElement('recordTriggerType', SOAP_NS, null).addTextNode(
            flowTriggerType
        );
        addConditionToStartElement(startElement, wfrRule, objectName, doesRequireRecordChangedToMeetCriteria);
        createSchedulePaths(flowXML, wfrRule, wfrXML, objectName);
        

        List<Dom.XmlNode> actionList = new List<Dom.XmlNode>();
        List<Dom.XmlNode> ruleActionList = ValidateWFRMetadata.getRuleActions(wfrRule);
        Integer alertCount = 1;
        for(Dom.XmlNode action : ruleActionList) {
            String actionType = ValidateWFRMetadata.getActionType(action);
            String actionName = ValidateWFRMetadata.getActionName(action);
            if(actionType == 'FieldUpdate') {
                
                Dom.XmlNode actionEntity = getAction(wfrXML,actionName);
                Dom.XmlNode convertedFlowAction = convertFieldUpdateAction(actionEntity, flowXML, objectName, null);
                sortXMLChildren(flowXML, convertedFlowAction, 'recordUpdates');
                if(convertedFlowAction != null) {
                    actionList.add(convertedFlowAction);
                }

            } else if(actionType == 'Alert') {

                Dom.XmlNode actionEntity = getAction(wfrXML, actionName);
                Dom.XmlNode convertedAlert = generateEmailAlert(actionEntity, flowXML, objectName, 'alert' + alertCount);
                sortXMLChildren(flowXML, convertedAlert, 'actionCalls');
                alertCount++;
                if(convertedAlert != null) {
                    actionList.add(convertedAlert);
                }

            } else if(actionType == 'Task') {

                Dom.XmlNode actionEntity = getAction(wfrXML, actionName);
                Dom.XmlNode convertedTask = generateNewTaskAction(actionEntity, flowXML, objectName, actionName);
                sortXMLChildren(flowXML, convertedTask, 'actionCalls');
                if(convertedTask != null) {
                    actionList.add(convertedTask);
                }

            }

        }

        for(Dom.XmlNode action : ruleActionList) {
            String actionType = ValidateWFRMetadata.getActionType(action);
            String actionName = ValidateWFRMetadata.getActionName(action);
            if(actionType == 'FieldUpdate') {
                
                Dom.XmlNode actionEntity = getAction(wfrXML,actionName);
                Dom.XmlNode convertedFlowAction = addFormulaForFieldUpdate(actionEntity, flowXML, objectName, '');
                if(convertedFlowAction != null) {
                    actionList.add(convertedFlowAction);
                }

            
            }

        }

        if(actionList.size() > 0) {
            Integer positionY = 500;
            Dom.XmlNode firstAction = actionList[0];
            
            startElement.addChildElement('connector', SOAP_NS, null)
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
    
        addConversionLog(flowXML);
        ConvertFlowMetadata.enableAutoLayout(flowXML);
       

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
    public static Dom.XmlNode addConversionLog(Dom.XmlNode flowXML){
        Dom.XmlNode processMetadata = flowXML.addChildElement('processMetadataValues', SOAP_NS, null);
            if(processMetadata != null){
            processMetadata.addChildElement('name', SOAP_NS, null).addTextNode('ConversionLog');
            Dom.XmlNode value = processMetadata.addChildElement('value', SOAP_NS, null);
            value.addChildElement('stringValue', SOAP_NS, null).addTextNode('ConvertedByConvertToFlow');
            }
        return null;
    }
    public static Dom.XmlNode convertFieldUpdateAction(Dom.XmlNode actionEntity, Dom.XmlNode flowXML, String objectName, String schedulePathName) {
        Dom.XmlNode  recordUpdate = flowXML.addChildElement('recordUpdates', SOAP_NS, null);
        String actionName = actionEntity.getChildElement('fullName', SOAP_NS).getText();
        if(!String.isEmpty(schedulePathName)) {
            actionName = schedulePathName + '_' + actionName;
        }

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

        if(operation == 'Formula') {
            
            Dom.XmlNode valueXML = actionEntity.getChildElement('formula', SOAP_NS);
            if(valueXML != null) {
                inputAssignments.addChildElement('value', SOAP_NS, null).addChildElement('elementReference', SOAP_NS, null).addTextNode(actionName + '_formula');
            }
        } else if(operation != 'Null') {
            Dom.XmlNode valueXML = actionEntity.getChildElement('literalValue', SOAP_NS);
            if(valueXML != null) {
                inputAssignments.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(valueXML.getText());
            }
        }

        return recordUpdate;
    }

    public static Dom.XmlNode addFormulaForFieldUpdate(Dom.XmlNode actionEntity, Dom.XmlNode flowXML, String objectName, String schedulePathName) {
        String actionName = actionEntity.getChildElement('fullName', SOAP_NS).getText();
        if(String.isNotEmpty(schedulePathName)) {
            actionName = schedulePathName + '_' + actionName;
        }
        String actionLabel = actionEntity.getChildElement('name', SOAP_NS).getText();
        String fieldName = actionEntity.getChildElement('field', SOAP_NS).getText();
        String operation = actionEntity.getChildElement('operation', SOAP_NS).getText();
        String fieldType = getFieldType(fieldName);
        System.debug('fieldType ' + fieldType);
        System.debug('fieldType ' + FORMULA_TYPE_MAP.get(fieldType));
        String formulaType = FORMULA_TYPE_MAP.get(fieldType);

        if(operation == 'Formula') {
            
            Dom.XmlNode valueXML = actionEntity.getChildElement('formula', SOAP_NS);
            if(valueXML != null) {
                String value = valueXML.getText();
                System.debug('fields + ' + ConvertWFRMetadata.sObjectFieldList);
                for(DescribeFieldResult field : ConvertWFRMetadata.sObjectFieldList) {
                    if(value.contains(field.getName())) {
                        value = value.replaceAll(''+ field.getName() +'(?!")', '{! \\$Record.' + field.getName() + '}');

                        System.debug(value);
                    }
                }
                Dom.XmlNode formulaNode = flowXML.addChildElement('formulas', SOAP_NS, null);
                formulaNode.addChildElement('name', SOAP_NS, null).addTextNode(actionName + '_formula');
                formulaNode.addChildElement('dataType', SOAP_NS, null).addTextNode(formulaType == null ? 'String' : formulaType);
                formulaNode.addChildElement('expression', SOAP_NS, null).addTextNode(value);
                sortXMLChildren(flowXML, formulaNode, 'formulas');
                
            }
        }

        return null;
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

    public static Dom.XmlNode generateNewTaskAction(Dom.XmlNode actionEntity, Dom.XmlNode flowXML, String objectName, String actionName) {

        Dom.XmlNode fulName = actionEntity.getChildElement('fullName', SOAP_NS);
        Dom.XmlNode assignedTo = actionEntity.getChildElement('assignedTo', SOAP_NS);
        Dom.XmlNode assignedToType = actionEntity.getChildElement('assignedToType', SOAP_NS);
        Dom.XmlNode dueDateOffset = actionEntity.getChildElement('dueDateOffset', SOAP_NS);
        Dom.XmlNode offsetFromField = actionEntity.getChildElement('offsetFromField', SOAP_NS);
        Dom.XmlNode priority = actionEntity.getChildElement('priority', SOAP_NS);
        Dom.XmlNode status = actionEntity.getChildElement('status', SOAP_NS);
        Dom.XmlNode subject = actionEntity.getChildElement('subject', SOAP_NS);

        Dom.XmlNode actionCall = flowXML.addChildElement('actionCalls', SOAP_NS, null);
        actionCall.addChildElement('name', SOAP_NS, null).addTextNode(actionName);
        actionCall.addChildElement('label', SOAP_NS, null).addTextNode(subject.getText());
        actionCall.addChildElement('actionName', SOAP_NS, null).addTextNode('NewTask');
        actionCall.addChildElement('actionType', SOAP_NS, null).addTextNode('quickAction');
        actionCall.addChildElement('flowTransactionModel', SOAP_NS, null).addTextNode('CurrentTransaction');
        
        Dom.XmlNode onwerIdInput = actionCall.addChildElement('inputParameters', SOAP_NS, null);
        Dom.XmlNode subjectInput = actionCall.addChildElement('inputParameters', SOAP_NS, null);
        Dom.XmlNode duedateInput = actionCall.addChildElement('inputParameters', SOAP_NS, null);
        Dom.XmlNode statusInput = actionCall.addChildElement('inputParameters', SOAP_NS, null);

        onwerIdInput.addChildElement('name', SOAP_NS, null).addTextNode('OwnerId');
        subjectInput.addChildElement('name', SOAP_NS, null).addTextNode('Subject');
        duedateInput.addChildElement('name', SOAP_NS, null).addTextNode('ActivityDate');
        statusInput.addChildElement('name', SOAP_NS, null).addTextNode('Status');

        if(assignedToType.getText() == 'owner') {
            onwerIdInput.addChildElement('value', SOAP_NS, null).addChildElement('elementReference', SOAP_NS, null).addTextNode('$Record.OwnerId');
        } else if(assignedToType.getText() == 'user') {
            onwerIdInput.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(userIdByUsernameMap.get(assignedTo.getText()));
        } else if(assignedToType.getText() == 'role') {
            onwerIdInput.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(roleIdByNameMap.get(assignedTo.getText()));
        }

        subjectInput.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(subject.getText());

        statusInput.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(status.getText());
        String dateFormulaExpression = '';
        if(offsetFromField == null) {
            dateFormulaExpression += '{! $System.OriginDateTime}';
        } else {
            dateFormulaExpression += '{! ' + offsetFromField.getText().replace(objectName, '$Record') +  '}';
        }
        if(dueDateOffset != null) {
            dateFormulaExpression += ' + ' + dueDateOffset.getText();
        }
        duedateInput.addChildElement('value', SOAP_NS, null).addChildElement('elementReference', SOAP_NS, null).addTextNode(actionName + '_formula');

        Dom.XmlNode formulaNode = flowXML.addChildElement('formulas', SOAP_NS, null);
        formulaNode.addChildElement('name', SOAP_NS, null).addTextNode(actionName + '_formula');
        formulaNode.addChildElement('dataType', SOAP_NS, null).addTextNode('Date');
        formulaNode.addChildElement('expression', SOAP_NS, null).addTextNode(dateFormulaExpression);
        sortXMLChildren(flowXML, formulaNode, 'formulas');
                
        return actionCall;
    } 

    public static Map<String, String> getUserIdByUsernameMap() {
        
        List<User> userList = [
            SELECT Id, Username FROM User LIMIT 50000
        ];

        Map<String, String> userIdByUsernameMap = new Map<String, String>();
    
        for( User u : userList) {
            userIdByUsernameMap.put(u.Username, u.Id);
        }
        return userIdByUsernameMap;

    }

    public static Map<String, String> getRoleIdByNameMap() {
        
        List<UserRole> userRoleList = [
            SELECT Id, Name FROM UserRole LIMIT 50000
        ];

        Map<String, String> roleIdByNameMap = new Map<String, String>();
    
        for( UserRole uRole : userRoleList) {
            roleIdByNameMap.put(uRole.Name, uRole.Id);
        }

        return roleIdByNameMap;

    }

    public static Dom.XmlNode addConditionToStartElement(Dom.XmlNode startElement, Dom.XmlNode wfrRule, String objectName, Boolean doesRequireRecordChangedToMeetCriteria) {
        

        if(doesRequireRecordChangedToMeetCriteria) {
            startElement.addChildElement('doesRequireRecordChangedToMeetCriteria', SOAP_NS, null).addTextNode('true');
        }

        Dom.XmlNode booleanFilter = wfrRule.getChildElement('booleanFilter', SOAP_NS);
        if(booleanFilter != null) {
            startElement.addChildElement('filterLogic', SOAP_NS, null).addTextNode(booleanFilter.getText());
        } else {
            startElement.addChildElement('filterLogic', SOAP_NS, null).addTextNode('and');
        }
        for(Dom.XmlNode criteriaItem : wfrRule.getChildren()) {
            if(criteriaItem.getName() == 'criteriaItems') {
                String field = criteriaItem.getChildElement('field', SOAP_NS).getText();
                String operator = criteriaItem.getChildElement('operation', SOAP_NS).getText();
                Dom.XmlNode valueXML = criteriaItem.getChildElement('value', SOAP_NS);
                String value = valueXML != null ? valueXML.getText() : '';
                Dom.XmlNode filters = startElement.addChildElement('filters', SOAP_NS, null);

                filters.addChildElement('operator', SOAP_NS, null).addTextNode(WFR_TO_FLOW_OPERATOR_MAP.get(operator));
                List<String> splitedField = field.split('\\.');
                field = '';
                if(splitedField.size() > 1) {
                    for(Integer i = 1; i < splitedField.size(); i++) {
                        field += splitedField[i]; 

                        if( i != splitedField.size() -1) {
                            field += '.';
                        }
                    }
                }
                
                filters.addChildElement('field', SOAP_NS, null).addTextNode(field);

                filters.addChildElement('value', SOAP_NS, null).addChildElement('stringValue', SOAP_NS, null).addTextNode(value);

            }
        }

        return startElement;
    }

    public static Dom.XmlNode createSchedulePaths(Dom.XmlNode flowXML, Dom.XmlNode wfrRule, Dom.XmlNode wfrXML, String objectName) {
        List<Dom.XmlNode> timeBaseTriggerList = XmlUtils.getChildrenByName(wfrRule, 'workflowTimeTriggers');
        Dom.XmlNode startElement = flowXML.getChildElement('start', SOAP_NS);
        System.debug('workflowTimeTriggers:' + timeBaseTriggerList);
        Integer scheduleCount = 1; 
        for(Dom.XmlNode timeBasedTrigger : timeBaseTriggerList){

            Dom.XmlNode offsetFromField = timeBasedTrigger.getChildElement('offsetFromField', SOAP_NS);
            Dom.XmlNode timeLength = timeBasedTrigger.getChildElement('timeLength', SOAP_NS);
            Dom.XmlNode workflowTimeTriggerUnit = timeBasedTrigger.getChildElement('workflowTimeTriggerUnit', SOAP_NS);
            Dom.XmlNode scheduledNode = startElement.addChildElement('scheduledPaths', SOAP_NS, null);

            scheduledNode.addChildElement('name', SOAP_NS,null).addTextNode('Scheduled_Path_' + scheduleCount);
            //scheduledNode.addChildElement('connector', SOAP_NS, null).addChildElement('targetReference', SOAP_NS, null).addTextNode(waitElements.connector);
            scheduledNode.addChildElement('label', SOAP_NS, null).addTextNode('Scheduled Path ' + scheduleCount);
            scheduledNode.addChildElement('offsetNumber', SOAP_NS, null).addTextNode(timeLength.getText());
            scheduledNode.addChildElement('offsetUnit', SOAP_NS, null).addTextNode(workflowTimeTriggerUnit.getText());

            List<Dom.XmlNode> actionList = new List<Dom.XmlNode>();
            List<Dom.XmlNode> actionNameList = ValidateWFRMetadata.getRuleActions(timeBasedTrigger);
            Integer alertCount = 1;
            for(Dom.XmlNode action : actionNameList) {
                String actionType = ValidateWFRMetadata.getActionType(action);
                String actionName = ValidateWFRMetadata.getActionName(action);
                if(actionType == 'FieldUpdate') {
                    
                    Dom.XmlNode actionEntity = getAction(wfrXML,actionName);
                    Dom.XmlNode convertedFlowAction = convertFieldUpdateAction(actionEntity, flowXML, objectName, 'Scheduled_Path_' + scheduleCount);
                    sortXMLChildren(flowXML, convertedFlowAction, 'recordUpdates');
                    if(convertedFlowAction != null) {
                        actionList.add(convertedFlowAction);
                    }

                    addFormulaForFieldUpdate(actionEntity, flowXML, objectName, 'Scheduled_Path_' + scheduleCount);
    
                } else if(actionType == 'Alert') {
    
                    Dom.XmlNode actionEntity = getAction(wfrXML, actionName);
                    Dom.XmlNode convertedAlert = generateEmailAlert(actionEntity, flowXML, objectName, 'Scheduled_Path_' + scheduleCount + '_alert' + alertCount);
                    
                    sortXMLChildren(flowXML, convertedAlert, 'actionCalls');
                    alertCount++;
                    if(convertedAlert != null) {
                        actionList.add(convertedAlert);
                    }
                }

                else if(actionType == 'Task') {
    
                    Dom.XmlNode actionEntity = getAction(wfrXML, actionName);
                    Dom.XmlNode convertedTask = generateNewTaskAction(actionEntity, flowXML, objectName, 'Scheduled_Path_' + scheduleCount + '_'+ actionName);
                    
                    sortXMLChildren(flowXML, convertedTask, 'actionCalls');
                    if(convertedTask != null) {
                        actionList.add(convertedTask);
                    }
                }
            }

            if(actionList.size() > 0) {
                Integer positionY = 500;
                Dom.XmlNode firstAction = actionList[0];
                
                scheduledNode.addChildElement('connector', SOAP_NS, null)
                    .addChildElement('targetReference', SOAP_NS, null)
                        .addTextNode(firstAction.getChildElement('name', SOAP_NS).getText());
                    
                firstAction.addChildElement('locationX', SOAP_NS, null).addTextNode(String.valueOf(500 * scheduleCount));
                firstAction.addChildElement('locationY', SOAP_NS, null).addTextNode(String.valueOf(positionY));
                positionY += 300;
                if(actionList.size() > 1) {
                    for(Integer i = 0; i < actionList.size() - 1; i++) {
                        actionList[i].addChildElement('connector', SOAP_NS, null)
                            .addChildElement('targetReference', SOAP_NS, null)
                                .addTextNode(actionList[i+1].getChildElement('name', SOAP_NS).getText());
                        actionList[i+1].addChildElement('locationX', SOAP_NS, null).addTextNode(String.valueOf(500 * scheduleCount));
                        actionList[i+1].addChildElement('locationY', SOAP_NS, null).addTextNode(String.valueOf(positionY));
                        positionY += 100;
                    }
                }
            }
            scheduleCount++;

            if(offsetFromField!= null) {
                scheduledNode.addChildElement('recordField', SOAP_NS, null).addTextNode(offsetFromField.getText().split('\\.')[1]);
            } else {
                scheduledNode.addChildElement('recordField', SOAP_NS, null).addTextNode('LastModifiedDate');
            }
            scheduledNode.addChildElement('timeSource', SOAP_NS, null).addTextNode('RecordField');
        }

        return null;
    }

    public static void sortXMLChildren(Dom.XmlNode flowXML, Dom.XmlNode node, String nodeName) {
        
        List<Dom.XmlNode> childList = XmlUtils.getChildrenByName(flowXml, nodeName);
        if(childList.size() > 1) {
            node.getParent().removeChild(node);
            childList = XmlUtils.getChildrenByName(flowXml, nodeName);
            if(childList != null && childList.size() > 0) {
                node = flowXML.insertBefore(node, childList[0]);
            }
        }      

    }

    public static List<DescribeFieldResult> getFields(String selectedObject){
        List<DescribeFieldResult> reqFields = new List<DescribeFieldResult>();
        Map <String,Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType sobjType = gd.get(selectedObject);
        Schema.DescribeSObjectResult r = sobjType.getDescribe();
        Map<String, Schema.SObjectField> MapofField = r.fields.getMap();
        
        for(String fieldName : MapofField.keySet()) {
            Schema.SObjectField field = MapofField.get(fieldName);
            Schema.DescribeFieldResult F = field.getDescribe();
	        reqFields.add(F);
        }
        return reqFields;
    }

    public static String getFieldType(String fieldName) {
        for(DescribeFieldResult field : ConvertWFRMetadata.sObjectFieldList) {
            if(field.getName() == fieldName) {
                return field.getType().name();
            }
        }
        return null;
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