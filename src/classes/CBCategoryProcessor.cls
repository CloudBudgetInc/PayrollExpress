/** 
Copyright (c) 04 2024, AJR, CloudBudget, Inc.
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

Special class to recalculate all type of category totals
 */
public with sharing class CBCategoryProcessor {

	private static String budgetYearId;
	private static String employeeId;
	private static Set<String> categoryIdOfBudgetLinesNeedToBeDeleted = new Set<String>();
	private static List<BudgetLineWrapper> budgetLineWrappersToInsert = new List<BudgetLineWrapper>();
	private static List<cb5__CBNonFinancialLibrary__c> NFLToUpdate = new List<cb5__CBNonFinancialLibrary__c>();
	private static List<cb5__CBNonFinancialItem__c> NFLItemsToUpdate = new List<cb5__CBNonFinancialItem__c>();
	private static List<CBCategory__c> categoriesToUpdate = new List<CBCategory__c>();
	private static List<cb5__CBPeriod__c> periods {
		get {
			if (periods == null) periods = [SELECT Id FROM cb5__CBPeriod__c WHERE cb5__CBBudgetYear__c = :budgetYearId ORDER BY cb5__Start__c];
			return periods;
		}
		set;
	}
	private static cb5__CBVariable5__c employee {
		get {
			if (employee == null) employee = CBEmployeeSelector.getEmployees(new Map<String, String>{
					'employeeId' => employeeId,
					'budgetYearId' => budgetYearId
			})[0];
			return employee;
		}
		set;
	}

	/**
	 * Current employee and current budget year categories
	 */
	private static List<CBCategory__c> categories {
		get {
			if (categories == null) {
				Map<String, String> params = new Map<String, String>{
						'budgetYearId' => budgetYearId,
						'employeeId' => employeeId
				};
				categories = CBCategorySelector.getCategories(params);
			}
			return categories;
		}
		set;
	}

	/**
	 *  key is category Id, value is result NFL
	 */
	private static Map<String, cb5__CBNonFinancialLibrary__c> resultNFLMap {
		get {
			if (resultNFLMap == null) {
				resultNFLMap = new Map<String, cb5__CBNonFinancialLibrary__c>();
				List<String> resultNFLIds = new List<String>();
				for (CBCategory__c c : categories) resultNFLIds.add(c.NFLResult__c);
				for (cb5__CBNonFinancialLibrary__c resultNFL : CBPayrollExpressPageController.getNFLServer(resultNFLIds, budgetYearId)) {
					for (CBCategory__c c : categories) {
						if (c.NFLResult__c == resultNFL.Id) resultNFLMap.put(c.Id, resultNFL);
					}
				}
			}
			return resultNFLMap;
		}
		set;
	}

	private static Map<Id, cb5__CBNonFinancialLibrary__c> engagedSourceNFLMap {
		get {
			if (engagedSourceNFLMap == null) {
				engagedSourceNFLMap = new Map<Id, cb5__CBNonFinancialLibrary__c>();
				Set<String> sourceNFLIds = new Set<String>();
				for (CBCategory__c c : categories) {
					sourceNFLIds.add(c.NFL1__c);
					sourceNFLIds.add(c.NFL2__c);
					sourceNFLIds.add(c.NFL3__c);
					sourceNFLIds.add(c.NFL4__c);
					sourceNFLIds.add(c.NFL5__c);
				}
				for (cb5__CBNonFinancialLibrary__c library : CBPayrollExpressPageController.getNFLServer(new List<String>(sourceNFLIds), budgetYearId)) {
					engagedSourceNFLMap.put(library.Id, library);
				}
			}
			return engagedSourceNFLMap;
		}
		set;
	}

	/**
	 * The Main method for saving Categories and Budget lines
	 *
	 * @param empId
	 * @param byId
	 */
	public static void updateOneEmployeeCategoriesAndBudgetLines(String empId, String byId) {
		System.debug('SAVE CATEGORIES AND BUDGET LINES');
		employeeId = empId;
		budgetYearId = byId;

		cb5__CBOrgVariable__c orgVariable = [SELECT cb5p__PayrollGroupingKey__c FROM cb5__CBOrgVariable__c LIMIT 1][0];
		deleteObsoleteBudgetLines(orgVariable.cb5p__PayrollGroupingKey__c);
		if (orgVariable.cb5p__PayrollGroupingKey__c == null) {
			System.debug('SINGLE MODE');
			updateOneEmployeeCategories();
			generateOneToOneBudgetLines();
		} else {

		}

		finalizeDatabaseDML();

	}

	private static void updateOneEmployeeCategories() {
		Integer idx = 0;
		for (CBCategory__c category : categories) { // each category generates a budget line
			System.debug('---------------- ' + String.valueOf(++idx) + ' Category:  ' + category.Name + ' ------------------------------');
			cb5__CBNonFinancialLibrary__c resultNFL = resultNFLMap.get(category.Id);
			List<cb5__CBNonFinancialItem__c> resultItems = resultNFL.cb5__NonFinancialItems__r;
			NFLItemsToUpdate.addAll(resultItems);
			if (category.ParentCategory__c == null) { // simple category with formula
				List<cb5__CBAmount__c> tmpAmounts = new List<cb5__CBAmount__c>();
				for (cb5__CBPeriod__c p : periods) tmpAmounts.add(new cb5__CBAmount__c(cb5__CBPeriod__c = p.Id, cb5__Value__c = 0));
				if (category.Formula__c != null) {
					List<List<cb5__CBNonFinancialItem__c>> sourceNFLItems = new List<List<cb5__CBNonFinancialItem__c>>();
					if (category.NFL1__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL1__c).cb5__NonFinancialItems__r);
					if (category.NFL2__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL2__c).cb5__NonFinancialItems__r);
					if (category.NFL3__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL3__c).cb5__NonFinancialItems__r);
					if (category.NFL4__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL4__c).cb5__NonFinancialItems__r);
					if (category.NFL5__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL5__c).cb5__NonFinancialItems__r);
					tmpAmounts = cb5.CBFormulaService.calculateFormulaTotals(tmpAmounts, sourceNFLItems, category.Formula__c);
				}
				for (Integer i = 0; i < resultItems.size(); i++) {
					resultItems[i].cb5__Value__c = tmpAmounts[i].cb5__Value__c;
				}
				if (category.TaxThreshold__c != null) {
					CBTaxThresholdProcessor.applyTaxThresholds(resultItems, category.TaxThreshold__c);
					System.debug('RES AFTER TAX : ' + resultItems);
				}
			} else { /// ALLOCATION
				List<cb5__CBNonFinancialItem__c> parentResultItems = engagedSourceNFLMap.get(category.NFL1__c).cb5__NonFinancialItems__r;
				Decimal allocationRate = category.Allocation__c == null ? 0 : category.Allocation__c;
				for (Integer i = 0; i < resultItems.size(); i++) {
					resultItems[i].cb5__Value__c = (parentResultItems[i].cb5__Value__c * allocationRate / 100).setScale(2);
				}
			}
			engagedSourceNFLMap.put(resultNFL.Id, resultNFL);
			System.debug('resultItems = ' + resultItems);
			categoriesToUpdate.add(category);
		}
	}

	private static void generateOneToOneBudgetLines() {
		for (CBCategory__c category : categories) {
			BudgetLineWrapper blw = new BudgetLineWrapper();
			budgetLineWrappersToInsert.add(blw); // new budget line must be added
			cb5__CBBudgetLine__c bl = new cb5__CBBudgetLine__c(cb5__CBBudgetYear__c = budgetYearId);
			bl.cb5__CBDivision__c = category.CBDivision__c != null ? category.CBDivision__c : employee.CBDivision__c;
			bl.Name = (employee.Name + ' (' + category.Name + ')').left(80);
			bl.cb5__CBVariable1__c = category.CBVariable1__c;
			bl.cb5__CBVariable2__c = category.CBVariable2__c;
			bl.cb5__CBVariable3__c = category.CBVariable3__c;
			bl.cb5__CBVariable4__c = category.CBVariable4__c;
			bl.cb5__CBVariable5__c = employeeId;
			bl.cb5__Lock__c = 'Editing';
			bl.CBCategory__c = category.Id;
			bl.cb5__CBAccount__c = category.CBAccount__c;
			bl.cb5__DrillDownIds__c = category.Id;
			blw.budgetLine = bl;
			cb5__CBNonFinancialLibrary__c resultNFL = resultNFLMap.get(category.Id);
			for (Integer i = 0; i < resultNFL.cb5__NonFinancialItems__r.size(); i++) {
				cb5__CBNonFinancialItem__c rItem = resultNFL.cb5__NonFinancialItems__r[i];
				blw.amounts.add(new cb5__CBAmount__c(cb5__Value__c = rItem.cb5__Value__c, cb5__CBPeriod__c = rItem.cb5__CBPeriod__c));
			}
		}
	}

	private static void deleteObsoleteBudgetLines(String grouping) {
		if (String.isEmpty(grouping)) {
			Set<Id> categoryIdOfBudgetLinesNeedToBeDeleted = new Set<Id>();
			for (CBCategory__c category : categories) categoryIdOfBudgetLinesNeedToBeDeleted.add(category.Id); // old budget line must be deleted
			delete [SELECT Id FROM cb5__CBBudgetLine__c WHERE CBCategory__c IN:categoryIdOfBudgetLinesNeedToBeDeleted];
		} else {

		}
	}

	private static void generateGroupBudgetLines() {

	}

	private static void finalizeDatabaseDML() {
		try {
			BudgetLineWrapper obj = new BudgetLineWrapper();
			System.debug('budgetLineWrappersToInsert = ' + budgetLineWrappersToInsert);
			obj.insertBudgetLineWrappers(budgetLineWrappersToInsert);
			obj.assignBLParentChildRelations(budgetLineWrappersToInsert, categories);
			update categoriesToUpdate;
			for (cb5__CBNonFinancialItem__c item : NFLItemsToUpdate) System.debug(item);
			update NFLItemsToUpdate;
		} catch (Exception e) {
			System.debug('FINALIZE EXCEPTION: ' + e);
			throw e;
		}
	}

/**
 * Wrapper for budget lines and amounts
 */
	public class BudgetLineWrapper {
		public cb5__CBBudgetLine__c budgetLine;
		public List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		public void insertBudgetLineWrappers(List<BudgetLineWrapper> budgetLineWrappers) {
			List<cb5__CBBudgetLine__c> budgetLines = new List<cb5__CBBudgetLine__c>();
			List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
			for (BudgetLineWrapper blw : budgetLineWrappers) {
				budgetLines.add(blw.budgetLine);
				amounts.addAll(blw.amounts);
			}
			insert budgetLines;
			for (BudgetLineWrapper blw : budgetLineWrappers)
				for (cb5__CBAmount__c a : blw.amounts) a.cb5__CBBudgetLine__c = blw.budgetLine.Id;
			insert amounts;
		}
		public void assignBLParentChildRelations(List<BudgetLineWrapper> budgetLineWrappers, List<CBCategory__c> categories) {
			Boolean noRelations = true;
			for (CBCategory__c cat : categories) if (cat.ParentCategory__c != null) noRelations = false;
			if (noRelations) return;
			Map<String, cb5__CBBudgetLine__c> BLMap = new Map<String, cb5__CBBudgetLine__c>();
			for (BudgetLineWrapper blw : budgetLineWrappers) {
				BLMap.put(blw.budgetLine.CBCategory__c, blw.budgetLine);
				blw.budgetLine.cb5__isAllocation__c = false; // back to default
			}
			for (CBCategory__c cat : categories) {
				if (cat.ParentCategory__c != null) {
					cb5__CBBudgetLine__c childBL = BLMap.get(cat.Id);
					cb5__CBBudgetLine__c parentBL = BLMap.get(cat.ParentCategory__c);
					childBL.cb5__ParentBudgetLine__c = parentBL.Id;
					parentBL.cb5__isAllocation__c = true;
				}
			}
			List<cb5__CBBudgetLine__c> budgetLines = new List<cb5__CBBudgetLine__c>();
			for (BudgetLineWrapper blw : budgetLineWrappers) budgetLines.add(blw.budgetLine);
			update budgetLines;
		}
	}

}