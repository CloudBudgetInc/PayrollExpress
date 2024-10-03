/** 
Copyright (c) 2024, AJR, CloudBudget, Inc.
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
public with sharing class CBPayrollTemplatePageController {

	public static final String FUNC_TYPE = 'Payroll Template';
	private static Map<String, String> oldResultNFLToNewResultNFLMap = new Map<String, String>();
	private static String functionId;
	private static String employeeId;
	private static String budgetYearId;
	private static List<CBCategory__c> templateCategories {
		get {
			if (templateCategories == null) {
				String jString = [SELECT cb5__Details__c FROM cb5__CBFunction__c WHERE Id = :functionId].cb5__Details__c;
				templateCategories = (List<CBCategory__c>) JSON.deserialize(jString, List<CBCategory__c>.class);
			}
			return templateCategories;
		}
		set;
	}

	@AuraEnabled
	public static List<cb5__CBFunction__c> getFunctionsServer() {
		return [SELECT Id, Name FROM cb5__CBFunction__c WHERE cb5__Type__c = :FUNC_TYPE ORDER BY Name LIMIT 100];
	}

	@AuraEnabled
	public static void savePayrollTemplateServer(String title, String empId, String byId) {
		if (empId == null || byId == null) return ;
		if (title == null || title.length() < 2) title = 'General';
		List<CBCategory__c> categories = CBCategorySelector.getCategories(new Map<String, String>{
				'employeeId' => empId,
				'budgetYearId' => byId
		});
		insert new cb5__CBFunction__c (Name = title, cb5__Type__c = FUNC_TYPE, cb5__Details__c = JSON.serialize(categories));
	}

	/**
	 * The main method to generate a new categories from saved template
	 * @param funcId configuration Is
	 * @param empId employee Id (Var5)
	 * @param byId budget year Id
	 */
	@AuraEnabled
	public static void applyPayrollTemplateServer(String funcId, String empId, String byId) {
		functionId = funcId;
		employeeId = empId;
		budgetYearId = byId;
		deleteOldCategories();
		List<CBCategory__c> newCategories = getNewCategoriesFromJSON();
		insert newCategories;
		replaceOldResultNFLWithNewOnes(newCategories);
	}

	/**
	 * Method deletes previous categories before creating a new one
	 */
	private static void deleteOldCategories() {
		delete [SELECT Id FROM CBCategory__c WHERE CBEmployee__c = :employeeId AND CBBudgetYear__c = :budgetYearId LIMIT 50000];
	}

	/**
	 * @return new categories based on configuration JSON
	 */
	private static List<CBCategory__c> getNewCategoriesFromJSON() {
		List<CBCategory__c> newCategories = new List<CBCategory__c>();
		Map<String, String> oldCustomNFLToNewNFL = getOldCustomNFLToNewNFLMap();
		for (CBCategory__c tmplCategory : templateCategories) {
			CBCategory__c newCategory = tmplCategory.clone(false, true, false, false);
			newCategory.CBEmployee__c = employeeId;
			newCategory.CBBudgetYear__c = budgetYearId;
			newCategory.NFLResult__c = null;
			newCategory.Value__c = 0;
			if (!oldCustomNFLToNewNFL.isEmpty()) {
				assignNewCustomNFLs(newCategory, oldCustomNFLToNewNFL);
			}
			newCategories.add(newCategory);
		}
		return newCategories;
	}

	/**
	 * @param templateCategories
	 * @return map where key is old custom NFL and value is a new custom NFL
	 */
	private static Map<String, String> getOldCustomNFLToNewNFLMap() {
		Set<String> usedNFLS = new Set<String>();
		for (CBCategory__c tmplCategory : templateCategories) {
			usedNFLS.add(tmplCategory.NFL1__c);
			usedNFLS.add(tmplCategory.NFL2__c);
			usedNFLS.add(tmplCategory.NFL3__c);
			usedNFLS.add(tmplCategory.NFL4__c);
			usedNFLS.add(tmplCategory.NFL5__c);
		}
		Map<String, String> customNFLMapLayers = new Map<String, String>();
		for (cb5__CBNonFinancialLibrary__c lib : [SELECT Id, cb5__Layer__c FROM cb5__CBNonFinancialLibrary__c WHERE Id IN:usedNFLS AND cb5__Type__c = 'Custom']) customNFLMapLayers.put(lib.Id, lib.cb5__Layer__c);
		Map<String, String> oldCustomNFLToNewNFL = new Map<String, String>();
		if (!customNFLMapLayers.isEmpty()) {
			List<cb5__CBNonFinancialLibrary__c> newCustomLibs = new List<cb5__CBNonFinancialLibrary__c>();
			for (String libId : customNFLMapLayers.keySet()) {
				String layerId = customNFLMapLayers.get(libId);
				newCustomLibs.add(new cb5__CBNonFinancialLibrary__c(Name = 'Custom', cb5__Type__c = 'Custom', cb5__Layer__c = layerId, cb5__Description__c = libId));
			}
			insert newCustomLibs;
			for (cb5__CBNonFinancialLibrary__c lib : newCustomLibs) oldCustomNFLToNewNFL.put(lib.cb5__Description__c, lib.Id);
		}
		return oldCustomNFLToNewNFL;
	}

	/**
	 * If a category has a custom NFL method will replace old custom NFL with a new custom NFL
	 * @param newCategory
	 * @param oldCustomNFLToNewNFL
	 */
	private static void assignNewCustomNFLs(CBCategory__c newCategory, Map<String, String> oldCustomNFLToNewNFL) {
		Map<String, String> fieldMappings = new Map<String, String>{
				'NFL1__c' => newCategory.NFL1__c,
				'NFL2__c' => newCategory.NFL2__c,
				'NFL3__c' => newCategory.NFL3__c,
				'NFL4__c' => newCategory.NFL4__c,
				'NFL5__c' => newCategory.NFL5__c
		};
		for (String fieldName : fieldMappings.keySet()) {
			String newNFL = oldCustomNFLToNewNFL.get(fieldMappings.get(fieldName));
			if (newNFL != null) newCategory.put(fieldName, newNFL);
		}
	}

	/**
	 * Method traces from old result NFL to a new ones if needed
	 * @param newCategories
	 */
	private static void replaceOldResultNFLWithNewOnes(List<CBCategory__c> newCategories) {
		Map<String, String> oldResultNFLToNewResultNFLMap = new Map<String, String>(); // key - old result, value = new result Id
		Set<String> newCategoryIds = new Set<String>(); // Ids of a newly inserted categories
		for (CBCategory__c cat : newCategories) newCategoryIds.add(cat.Id); // populating new category Ids
		Map<Id, CBCategory__c> categoryMap = new Map<Id, CBCategory__c>([SELECT Id,NFLResult__c FROM CBCategory__c WHERE Id IN :newCategoryIds]);
		for (Integer i = 0; i < newCategories.size(); i++) { // iterate over new categories saving order
			CBCategory__c cat = newCategories[i]; // new category
			String newResultNFLId = categoryMap.get(cat.Id).NFLResult__c; // new category result NFL Id
			String oldResultNFLId = templateCategories[i].NFLResult__c; // old category result NFL Id
			oldResultNFLToNewResultNFLMap.put(oldResultNFLId, newResultNFLId); // key - old result NFL Id, value = new result NFL Id
		}
		for (CBCategory__c cat : newCategories) { // iteration over new categories to replace some NFL_X with old result NFL to a new result NFL
			for (String field : new List<String>{
					'NFL1__c', 'NFL2__c', 'NFL3__c', 'NFL4__c', 'NFL5__c'
			}) {
				cat.NFLResult__c = categoryMap.get(cat.Id).NFLResult__c;
				String newResultNFLId = oldResultNFLToNewResultNFLMap.get((String) cat.get(field));
				if (newResultNFLId != null) cat.put(field, newResultNFLId);
			}
		}
		update newCategories;
	}
}