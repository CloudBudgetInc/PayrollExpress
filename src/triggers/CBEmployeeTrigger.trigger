/**
 * Created by Alex JR on 6/24/2024.
 */

trigger CBEmployeeTrigger on cb5__CBVariable5__c (after insert, after update) {

	String layerId = [SELECT Id FROM cb5__CBLayer__c WHERE Name = 'Salary'][0].Id;

	if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
		Map<String, cb5__CBNonFinancialLibrary__c> libMap = new Map<String, cb5__CBNonFinancialLibrary__c>();
		for (cb5__CBNonFinancialLibrary__c lib : [SELECT Name FROM cb5__CBNonFinancialLibrary__c WHERE cb5__Layer__c = :layerId]) {
			libMap.put(lib.Name, lib);
		}

		List<cb5__CBNonFinancialLibrary__c> librariesToUpdate = new List<cb5__CBNonFinancialLibrary__c>();
		List<List<cb5__CBNonFinancialItem__c>> listOfListOfItems = new List<List<cb5__CBNonFinancialItem__c>>();

		for (cb5__CBVariable5__c emp : Trigger.new) {
			if (emp.YearlySalary__c == null || emp.YearlySalary__c == 0) continue;
			cb5__CBNonFinancialLibrary__c lib = libMap.get(emp.Name);
			if (lib == null) {
				lib = new cb5__CBNonFinancialLibrary__c(cb5__Layer__c = layerId, Name = emp.Name);
			}
			librariesToUpdate.add(lib);
		}
		upsert librariesToUpdate; // items will be created automatically
		Set<Id> libSetId = new Set<Id>();
		for (cb5__CBNonFinancialLibrary__c lib : librariesToUpdate) libSetId.add(lib.Id);

		libMap.clear();
		for (cb5__CBNonFinancialLibrary__c lib : [SELECT Id, Name, (SELECT Id FROM cb5__NonFinancialItems__r) FROM cb5__CBNonFinancialLibrary__c WHERE Id IN:libSetId]) {
			libMap.put(lib.Name, lib);
		}

		List<cb5__CBNonFinancialItem__c> itemsToUpdate = new List<cb5__CBNonFinancialItem__c>();
		for (cb5__CBVariable5__c emp : Trigger.new) {
			if (emp.YearlySalary__c == null || emp.YearlySalary__c == 0) continue;
			Decimal monthlySalary = (emp.YearlySalary__c / 12).setScale(2);
			List<cb5__CBNonFinancialItem__c> items = libMap.get(emp.Name).cb5__NonFinancialItems__r;
			for (cb5__CBNonFinancialItem__c i : items) i.cb5__Value__c = monthlySalary;
			itemsToUpdate.addAll(items);
		}
		update itemsToUpdate;
	}

}