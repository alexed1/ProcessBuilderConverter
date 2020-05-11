global with sharing class GenerateFlow {
public GenerateFlow() {

}

@InvocableMethod(label='GenerateFlow' )
public static List<FlowGenResult> GenerateFlow(List<FlowGenRequest> parameters){
	String res = '';

	try{

		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = UserInfo.getSessionId();

		FlowGenRequest vars = parameters[0];

		MetadataService.Flow flow = FlowService.createFlowInMemory(vars.SubflowName);

		//subflow creation
		MetadataService.FlowSubflow subflow = new MetadataService.FlowSubflow();
		subflow.flowName = vars.FoundationFlowName;
		subflow.name = 'Subflow';
		subflow.label = 'Subflow';
		subflow.description = 'Subflow that calls a flow named: ' + vars.FoundationFlowName;
		subflow.locationX = 100;
		subflow.locationY = 100;

		subflow.inputAssignments = new List<MetadataService.FlowSubflowInputAssignment>();

		FlowService.addSubflowInputAssignmentValue(subflow, 'ShowContactScreen', vars.ShowContactScreen);
		FlowService.addSubflowInputAssignmentValue(subflow, 'ShowOpportunityScreen', vars.ShowOpportunityScreen);
		FlowService.addSubflowInputAssignmentValue(subflow, 'TaskGuidanceStatus', vars.ShowTaskScreen);
		FlowService.addSubflowInputAssignmentValue(subflow, 'ValidateTaskInput', vars.ValidateTaskInput);

		flow.subflows = new List<MetadataService.FlowSubflow>{subflow};
		flow.startElementReference = 'Subflow';
		FlowService.saveFlow(service, flow);

		res = 'Flow has been succesfully generated!';

	}
	catch(Exception exc) {
		res = 'Something went wrong: ' +res + ' error: ' + exc.getMessage();
	}


	FlowGenResult flowGenResult = new FlowGenResult();
	flowGenResult.passedValues = res;
	List<GenerateFlow.FlowGenResult> returnResult = new List<GenerateFlow.FlowGenResult>();
	returnResult.add(flowGenResult);
	return returnResult;
}



global class FlowGenRequest {
@InvocableVariable(required=true)
global Boolean ShowContactScreen;

@InvocableVariable(required=true)
global Boolean ShowOpportunityScreen;

@InvocableVariable(required=true)
global String ShowTaskScreen;

@InvocableVariable(required=true)
global Boolean ValidateTaskInput;

@InvocableVariable(required=true)
global String FoundationFlowName;

@InvocableVariable(required=true)
global String SubflowName;

}

global class FlowGenResult {

@InvocableVariable
global String passedValues;
}

public class FlowGenException extends Exception {}
}
