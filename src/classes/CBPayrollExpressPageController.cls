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

	/**
	 * @param params (budgetYearId, employeeId, )
	 *
	 * @return list of Var (Employees) created
	 */
	@AuraEnabled
	public static List<cb5__CBVariable5__c> getEmployeesServer(Map<String, String> params) {
		return CBEmployeeSelector.getEmployees(params);
	}

	/**
	 * @param params  (budgetYearId, employeeId )
	 *
	 * @return list of categories ordered by index
	 */
	@AuraEnabled
	public static List<CBCategory__c> getCategoriesServer(Map<String, String> params) {
		return CBCategorySelector.getCategories(params);
	}

	/**
	 * @param nflIds list of needed for category NFLs
	 * @param budgetYearId amounts just for selected budget year
	 *
	 * @return needed for category NFLs
	 */
	@AuraEnabled
	public static List<cb5__CBNonFinancialLibrary__c> getNFLServer(List<String> nflIds, String budgetYearId) {
		Set<String> nflIdSet = new Set<String> (nflIds);
		return [
				SELECT Id,Name,cb5__Layer__c,cb5__LayerTitle__c,cb5__Type__c,
						cb5__Layer__r.cb5__Unit__c, (
						SELECT Id,cb5__Value__c,cb5__CBPeriod__c,cb5__CBPeriod__r.Name
						FROM cb5__NonFinancialItems__r
						WHERE cb5__CBPeriod__r.cb5__CBBudgetYear__c = :budgetYearId
						ORDER BY cb5__CBPeriod__r.cb5__Start__c
				)
				FROM cb5__CBNonFinancialLibrary__c
				WHERE Id IN:nflIdSet
		];
	}

	/**
	 * @return analytics for the main page filter dropdown
	 */
	@AuraEnabled
	public static String getDefaultBudgetYearIdServer() {
		cb5__CBPeriod__c currentPeriod = [SELECT cb5__CBBudgetYear__c FROM cb5__CBPeriod__c WHERE cb5__Start__c = :Date.today().toStartOfMonth() LIMIT 1];
		if (currentPeriod != null) return currentPeriod.cb5__CBBudgetYear__c;
		return [SELECT Id FROM cb5__CBBudgetYear__c LIMIT 1][0].Id;
	}

	/**
	 * @param employee processed employee need to be saved
	 * @param byId selected budget year
	 *
	 * @return updated employee
	 */
	@AuraEnabled
	public static cb5__CBVariable5__c saveEmployeeServer(cb5__CBVariable5__c employee, String byId) {
		update employee;
		CBCategoryProcessor.updateEmployeeCategories(employee.Id, byId);
		return employee;
	}

	/**
	 * @param category category to save
	 * @param resultItems each category has NFL with result amounts per one budget year
	 *
	 * @return Id of saved category
	 */
	@AuraEnabled
	public static String saveCategoryServer(CBCategory__c category) {
		upsert category;
		return category.Id;
	}
	/**
	 * New category might be saved on server first, because trigger must create result NFL
	 */
	@AuraEnabled
	public static void saveNewCategoryServer(CBCategory__c category) {
		category.CBAccount__c = getRespectiveCategoryAccountServer(category);
		insert category;
	}

	@AuraEnabled
	public static Id getRespectiveCategoryAccountServer(CBCategory__c category) {
		List<CBCategory__c> categories = [SELECT cb5p__CBAccount__c FROM CBCategory__c WHERE Type__c = :category.Type__c AND cb5p__CBDivision__c = :category.CBDivision__c LIMIT 1];
		if (categories.size() > 0) return categories[0].cb5p__CBAccount__c;
		categories = [SELECT cb5p__CBAccount__c FROM CBCategory__c WHERE Type__c = :category.Type__c LIMIT 1];
		if (categories.size() > 0) return categories[0].cb5p__CBAccount__c;
		return [SELECT Id FROM cb5__CBAccount__c LIMIT 1][0].Id;
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

	/**
	 * @param categoryId
	 */
	@AuraEnabled
	public static void deleteCategoryServer(String categoryId) {
		Database.delete(categoryId);
	}

	/**
	 * @param employeeId - processed employee Id
	 *
	 * @return list of NFLs related to this employee
	 */
	@AuraEnabled
	public static List<cb5__CBNonFinancialLibrary__c> getRecentNFLsServer(String employeeId, String budgetYearId) {
		Set<String> recentNFLs = new Set<String>();
		for (CBCategory__c cat : [
				SELECT NFLResult__c,NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c
				FROM CBCategory__c
				WHERE CBEmployee__c = :employeeId AND CBBudgetYear__c = :budgetYearId
		]) {
			recentNFLs.add(cat.NFLResult__c);
			recentNFLs.add(cat.NFL1__c);
			recentNFLs.add(cat.NFL2__c);
			recentNFLs.add(cat.NFL3__c);
			recentNFLs.add(cat.NFL4__c);
			recentNFLs.add(cat.NFL5__c);
		}
		return [SELECT Id,Name,cb5__LayerTitle__c FROM cb5__CBNonFinancialLibrary__c WHERE Id IN:recentNFLs];
	}

	/**
	 * @return all Thresholds in the system. 
	 */
	@AuraEnabled
	public static List<cb5__CBNonFinancialLibrary__c> getTaxThresholdsServer() {
		return [
				SELECT Id,Name,NFL1__c,NFL2__c,NFL3__c,NFL4__c,NFL5__c,
						NFL1__r.From__c,NFL1__r.cb5p__UpTo__c,NFL1__r.cb5__SingleValue__c,
						NFL2__r.From__c,NFL2__r.cb5p__UpTo__c,NFL2__r.cb5__SingleValue__c,
						NFL3__r.From__c,NFL3__r.cb5p__UpTo__c,NFL3__r.cb5__SingleValue__c,
						NFL4__r.From__c,NFL4__r.cb5p__UpTo__c,NFL4__r.cb5__SingleValue__c,
						NFL5__r.From__c,NFL5__r.cb5p__UpTo__c,NFL5__r.cb5__SingleValue__c
				FROM cb5__CBNonFinancialLibrary__c
				WHERE cb5__Type__c = 'Tax'
				LIMIT 100
		];
	}

	/**
	 * @param nflLib quick save for Threshold numbers
	 */
	@AuraEnabled
	public static void saveTaxThresholdsServer(cb5__CBNonFinancialLibrary__c nflLib) {
		upsert nflLib;
	}

	/**
	 * @param items quick save for Threshold numbers
	 */
	@AuraEnabled
	public static void saveNFLItemsServer(List<cb5__CBNonFinancialItem__c> items) {
		upsert items;
	}

	/**
	 * @param library temporary solution to use single value in all nfl items
	 */
	@AuraEnabled
	public static void saveNFLibraryServer(cb5__CBNonFinancialLibrary__c library) {
		List<cb5__CBNonFinancialItem__c> items = [SELECT Id FROM cb5__CBNonFinancialItem__c WHERE cb5__NonFinancialLibrary__c = :library.Id];
		for (cb5__CBNonFinancialItem__c item : items) item.cb5__Value__c = library.cb5__SingleValue__c;
		upsert library;
		upsert items;
	}

	/**
	 * Creating a new Threshold in server first
	 */
	@AuraEnabled
	public static void addTaxThresholdServer() {
		List<cb5__CBLayer__c> layers = [SELECT Id FROM cb5__CBLayer__c WHERE Name LIKE '%tax%'];
		insert new cb5__CBNonFinancialLibrary__c(Name = 'New', cb5__Type__c = 'Tax', cb5__Layer__c = layers[0].Id);
	}

	/**
	 * @param nflId id of Threshold need to be deleted
	 */
	@AuraEnabled
	public static void deleteTaxThresholdServer(String nflId) {
		Database.delete(nflId);
	}

	/**
	 * @param parentCategoryId parent allocation category Id
	 * @return index on newly allocated category
	 */
	@AuraEnabled
	public static Decimal setAllocatedAndGetChildIndexServer(String parentCategoryId) {
		CBCategory__c parentCategory = [SELECT Id,Index__c, (SELECT Id FROM CBCategories__r) FROM CBCategory__c WHERE Id = :parentCategoryId];
		parentCategory.isAllocated__c = true;
		update parentCategory;
		return parentCategory.Index__c + Decimal.valueOf((parentCategory.CBCategories__r.size() + 1)) / 10;
	}

	/**
	 * @param layerId layer Id of new NFL
	 * @return
	 */
	@AuraEnabled
	public static String createNewNFLServer(String layerId) {
		cb5__CBNonFinancialLibrary__c newNFL = new cb5__CBNonFinancialLibrary__c(Name = 'Custom', cb5__Type__c = 'Custom', cb5__Layer__c = layerId);
		insert newNFL;
		return newNFL.Id;
	}

	@AuraEnabled
	public static ChartWrapper getChartDataServer(List<String> categoryIds, String budgetYearId) {
		ChartWrapper r = new ChartWrapper();
		Map<String, Decimal> employeeValue = new Map<String, Decimal>();
		Map<String, Decimal> typeValue = new Map<String, Decimal>();
		Map<String, Map<String, Decimal>> typePeriodValue = new Map<String, Map<String, Decimal>>();
		Set<String> resultNFLIds = new Set<String>();
		Map<String, String> resNFLIdToTypeMap = new Map<String, String>();

		for (CBCategory__c cat : [SELECT Id,Type__c,CBEmployee__r.Name,CBEmployee__c,NFLResult__c,Value__c FROM CBCategory__c WHERE Id IN:categoryIds]) {
			Decimal oldValue = typeValue.get(cat.Type__c);
			typeValue.put(cat.Type__c, oldValue != null ? oldValue + cat.Value__c : cat.Value__c);
			oldValue = employeeValue.get(cat.CBEmployee__r.Name);
			employeeValue.put(cat.CBEmployee__r.Name, oldValue != null ? oldValue + cat.Value__c : cat.Value__c);
			resultNFLIds.add(cat.NFLResult__c);
			resNFLIdToTypeMap.put(cat.NFLResult__c, cat.Type__c);
		}

		for (cb5__CBNonFinancialLibrary__c lib : [
				SELECT Id, (SELECT cb5__CBPeriod__r.Name, cb5__Value__c FROM cb5__NonFinancialItems__r WHERE cb5__CBPeriod__r.cb5__CBBudgetYear__c = :budgetYearId ORDER BY cb5__CBPeriod__r.cb5__Start__c)
				FROM cb5__CBNonFinancialLibrary__c
				WHERE Id IN:resultNFLIds
		]) {
			String type = resNFLIdToTypeMap.get(lib.Id);
			Map<String, Decimal> periodValueMap = typePeriodValue.get(type);
			if (periodValueMap == null) {
				periodValueMap = new Map<String, Decimal>();
				typePeriodValue.put(type, periodValueMap);
			}
			Map<String, Decimal> totalPeriodValueMap = typePeriodValue.get('TOTAL');
			if (totalPeriodValueMap == null) {
				totalPeriodValueMap = new Map<String, Decimal>();
				typePeriodValue.put('TOTAL', totalPeriodValueMap);
			}
			for (cb5__CBNonFinancialItem__c item : lib.cb5__NonFinancialItems__r) {
				Decimal oldValue = periodValueMap.get(item.cb5__CBPeriod__r.Name);
				periodValueMap.put(item.cb5__CBPeriod__r.Name, oldValue != null ? oldValue + item.cb5__Value__c : item.cb5__Value__c);
				Decimal totalOldValue = totalPeriodValueMap.get(item.cb5__CBPeriod__r.Name);
				totalPeriodValueMap.put(item.cb5__CBPeriod__r.Name, totalOldValue != null ? totalOldValue + item.cb5__Value__c : item.cb5__Value__c);
			}
		}

		r.employeeValue = employeeValue;
		r.typeValue = typeValue;
		r.typePeriodValue = typePeriodValue;
		return r;
	}

	@AuraEnabled
	public static Boolean checkSetupServer() {
		Schema.DescribeFieldResult fieldResult = cb5__CBNonFinancialLibrary__c.cb5__Type__c.getDescribe();
		List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
		Boolean isResultPresent = false;
		for (Schema.PicklistEntry entry : picklistValues) {
			if (entry.getLabel() == 'Result') {
				isResultPresent = true;
				break;
			}
		}
		fieldResult = cb5__CBFunction__c.cb5__Type__c.getDescribe();
		picklistValues = fieldResult.getPicklistValues();
		Boolean isPRTemplatePresent = false;
		for (Schema.PicklistEntry entry : picklistValues) {
			if (entry.getLabel() == CBPayrollTemplatePageController.FUNC_TYPE) {
				isPRTemplatePresent = true;
				break;
			}
		}
		return isResultPresent && isPRTemplatePresent;
	}

	public class ChartWrapper {
		@AuraEnabled
		public Map<String, Map<String, Decimal>> typePeriodValue { get; set; }

		@AuraEnabled
		public Map<String, Decimal> employeeValue { get; set; }

		@AuraEnabled
		public Map<String, Decimal> typeValue { get; set; }
	}


}