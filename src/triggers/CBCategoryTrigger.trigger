/**
 * Created by Alex JR on 4/11/2024.
 */

trigger CBCategoryTrigger on CBCategory__c (after insert, before delete) {

	if (Trigger.isInsert && Trigger.isAfter) {
		Set<String> catIds = new Set<String>();
		for (CBCategory__c c : Trigger.new) catIds.add(c.Id);
		List<CBCategory__c> categories = [SELECT Id FROM CBCategory__c WHERE Id IN:catIds];

		String categoryLayerId = [SELECT Id FROM cb5__CBLayer__c WHERE Name = 'Category'][0].Id;
		List<cb5__CBNonFinancialLibrary__c> results = new List<cb5__CBNonFinancialLibrary__c>();
		for (CBCategory__c category : categories) {
			results.add(new cb5__CBNonFinancialLibrary__c(cb5__Layer__c = categoryLayerId, Name = 'Result', cb5__Type__c = 'Result'));
		}
		insert results;
		for (Integer i = 0; i < categories.size(); i++) {
			categories[i].NFLResult__c = results[i].Id;
		}
		update categories;
	}

	if (Trigger.isBefore && Trigger.isDelete) {
		Set<String> deletedCategoryIds = new Set<String>();
		Set<String> employeeIds = new Set<String>();
		Set<String> NFLIdNeedToBeDeleted = new Set<String>();
		for (CBCategory__c cat : Trigger.old) {
			deletedCategoryIds.add(cat.Id);
			NFLIdNeedToBeDeleted.add(cat.cb5p__NFLResult__c);
		}
		delete [SELECT Id FROM cb5__CBBudgetLine__c WHERE CBCategory__c IN:deletedCategoryIds];
		delete [SELECT Id FROM cb5__CBNonFinancialLibrary__c WHERE cb5__LayerTitle__c = 'Category' AND Id IN: NFLIdNeedToBeDeleted];
	}

}