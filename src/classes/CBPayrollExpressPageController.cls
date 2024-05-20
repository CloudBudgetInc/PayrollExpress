/**
Copyright (c) 2024, CloudBudget, Inc.
All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
* Neither the name of the CloudBudget, Inc. nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.

 */
public class CBPayrollExpressPageController {

	@AuraEnabled
	public static List<cb5__CBVariable5__c> getEmployeesServer(Map<String, String> params) {
		return CBEmployeeSelector.getEmployees(params);
	}

	@AuraEnabled
	public static List<CBCategory__c> getCategoriesServer(Map<String, String> params) {
		return CBCategorySelector.getCategories(params);
	}

	@AuraEnabled
	public static List<cb5__CBNonFinancialLibrary__c> getNFLServer(List<String> nflIds, String budgetYearId) {
		Set<String> nflIdSet = new Set<String> (nflIds);
		return [
				SELECT Id,Name,cb5__Layer__c,cb5__LayerTitle__c,cb5__Type__c, (
						SELECT Id,cb5__Value__c,cb5__CBPeriod__c,cb5__CBPeriod__r.Name
						FROM cb5__NonFinancialItems__r
						WHERE cb5__CBPeriod__r.cb5__CBBudgetYear__c = :budgetYearId
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				)
				FROM cb5__CBNonFinancialLibrary__c
				WHERE Id IN:nflIdSet
		];
	}


	@AuraEnabled
	public static Map<String, Map<String, String>> getAnalyticsServer() {
		Map<String, Map<String, String>> r = new Map<String, Map<String, String>>();

		Map<String, String> division = new Map<String, String>();
		for (cb5__CBDivision__c div : [SELECT Id, Name FROM cb5__CBDivision__c ORDER BY Name]) division.put(div.Id, div.Name);
		r.put('division', division);

		Map<String, String> budgetYear = new Map<String, String>();
		for (cb5__CBBudgetYear__c bYear : [SELECT Id, Name FROM cb5__CBBudgetYear__c ORDER BY Name]) budgetYear.put(bYear.Id, bYear.Name);
		r.put('budgetYear', budgetYear);

		Map<String, String> employee = new Map<String, String>();
		for (cb5__CBVariable5__c emp : [SELECT Id, Name FROM cb5__CBVariable5__c ORDER BY Name]) employee.put(emp.Id, emp.Name);
		r.put('employee', employee);

		return r;
	}

	@AuraEnabled
	public static cb5__CBVariable5__c saveEmployeeServer(cb5__CBVariable5__c employee, String byId) {
		update employee;
		CBCategoryProcessor.updateEmployeeCategories(employee.Id, byId);
		return employee;
	}

	@AuraEnabled
	public static String saveCategoryServer(CBCategory__c category, List<cb5__CBNonFinancialItem__c> resultItems) {
		if (resultItems != null && resultItems.size() > 0) update resultItems;
		upsert category;
		return category.Id;
	}

	@AuraEnabled
	public static void saveNewCategoryServer(CBCategory__c category) {
		category.CBAccount__c = [SELECT Id FROM cb5__CBAccount__c LIMIT 1][0].Id;
		insert category;
	}

	/**
	 * @param categoryId Id of the category need to be deleted
	 * @return true if sibling categories do not use the category result line
	 */
	@AuraEnabled
	public static Boolean categoryCanBeDeletedSafelyServer(String categoryId) {
		CBCategory__c cat = [SELECT CBEmployee__c, NFLResult__c, CBBudgetYear__c FROM CBCategory__c WHERE Id = :categoryId];
		List<CBCategory__c> siblingCategories = [
				SELECT Id
				FROM CBCategory__c
				WHERE CBEmployee__c = :cat.CBEmployee__c AND CBBudgetYear__c = :cat.CBBudgetYear__c AND (
						NFL1__c = :cat.NFLResult__c OR NFL2__c = :cat.NFLResult__c OR NFL3__c = :cat.NFLResult__c OR NFL4__c = :cat.NFLResult__c OR NFL5__c = :cat.NFLResult__c
				)
		];
		return siblingCategories.size() == 0;
	}

	@AuraEnabled
	public static void deleteCategoryServer(String categoryId) {
		Database.delete(categoryId);
	}

	@AuraEnabled
	public static List<cb5__CBNonFinancialLibrary__c> getRecentNFLsServer(String employeeId) {
		Set<String> recentNFLs = new Set<String>();
		for (CBCategory__c cat : [SELECT NFLResult__c,NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c FROM CBCategory__c WHERE CBEmployee__c = :employeeId]) {
			recentNFLs.add(cat.NFLResult__c);
			recentNFLs.add(cat.NFL1__c);
			recentNFLs.add(cat.NFL2__c);
			recentNFLs.add(cat.NFL3__c);
			recentNFLs.add(cat.NFL4__c);
			recentNFLs.add(cat.NFL5__c);
		}
		return [SELECT Id,Name,cb5__LayerTitle__c FROM cb5__CBNonFinancialLibrary__c WHERE Id IN:recentNFLs];
	}

	@AuraEnabled
	public static List<cb5__CBNonFinancialLibrary__c> getTaxThresholdsServer() {
		return [
				SELECT Id,Name,NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c,
						NFL1__r.From__c,NFL1__r.Till__c,NFL1__r.cb5__SingleValue__c,
						NFL2__r.From__c,NFL2__r.Till__c,NFL2__r.cb5__SingleValue__c,
						NFL3__r.From__c,NFL3__r.Till__c,NFL3__r.cb5__SingleValue__c,
						NFL4__r.From__c,NFL4__r.Till__c,NFL4__r.cb5__SingleValue__c,
						NFL5__r.From__c,NFL5__r.Till__c,NFL5__r.cb5__SingleValue__c
				FROM cb5__CBNonFinancialLibrary__c
				WHERE cb5__Type__c = 'Tax'
				LIMIT 100
		];
	}

	@AuraEnabled
	public static void saveTaxThresholdsServer(cb5__CBNonFinancialLibrary__c nflLib) {
		upsert nflLib;
	}

	@AuraEnabled
	public static void saveNFLibraryServer(cb5__CBNonFinancialLibrary__c library) {
		List<cb5__CBNonFinancialItem__c> items = [SELECT Id FROM cb5__CBNonFinancialItem__c WHERE cb5__NonFinancialLibrary__c = :library.Id];
		for (cb5__CBNonFinancialItem__c item : items) item.cb5__Value__c = library.cb5__SingleValue__c;
		System.debug('Library: ' + library);
		upsert library;
		upsert items;
	}

	@AuraEnabled
	public static void addTaxThresholdServer() {
		List<cb5__CBLayer__c> layers = [SELECT Id FROM cb5__CBLayer__c WHERE Name LIKE '%tax%'];
		insert new cb5__CBNonFinancialLibrary__c(Name = 'New', cb5__Type__c = 'Tax', cb5__Layer__c = layers[0].Id);
	}

	@AuraEnabled
	public static void deleteTaxThresholdServer(String nflId) {
		Database.delete(nflId);
	}

	@AuraEnabled
	public static Decimal setAllocatedAndGetChildIndexServer(String parentCategoryId) {
		CBCategory__c parentCategory = [SELECT Id,Index__c, (SELECT Id FROM CBCategories__r) FROM CBCategory__c WHERE Id = :parentCategoryId];
		parentCategory.isAllocated__c = true;
		update parentCategory;
		return parentCategory.Index__c + Decimal.valueOf((parentCategory.CBCategories__r.size() + 1)) / 10;
	}


}