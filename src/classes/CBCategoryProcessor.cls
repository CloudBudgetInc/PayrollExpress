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
	private static Set<String> budgetLineIdsToDelete = new Set<String>();
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

	private static Map<String, cb5__CBNonFinancialLibrary__c> resultNFLMap { // key is category Id, value is result NFL
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
	 * The main class to regenerate budget lines and category totals
	 * One run per one employee and one budget year
	 * @param empId - processed employee Id
	 * @param byId - processed budget year Id
	 */
	public static void updateEmployeeCategories(String empId, String byId) {
		if (empId == null || byId == null) return;
		budgetYearId = byId;
		employeeId = empId;
		for (CBCategory__c category : categories) {
			List<cb5__CBAmount__c> calculatedAmounts = updateBudgetLineAndReturnCalculatedAmounts(category);
			updateCategoryResult(category, calculatedAmounts);
		}
		finalizeDML();
	}

	/**
	 * This method updates budget lines witch will be source for the category amounts
	 * @param category processed category
	 * @return list of budget line amounts
	 */
	private static List<cb5__CBAmount__c> updateBudgetLineAndReturnCalculatedAmounts(CBCategory__c category) {
		BudgetLineWrapper blw = new BudgetLineWrapper();
		budgetLineIdsToDelete.add(category.Id); // old budget line must be deleted
		budgetLineWrappersToInsert.add(blw); // new budget line must be added
		cb5__CBBudgetLine__c bl = new cb5__CBBudgetLine__c(cb5__CBBudgetYear__c = budgetYearId);
		bl.cb5__CBDivision__c = category.CBDivision__c != null ? category.CBDivision__c : employee.CBDivision__c;
		bl.Name = (employee.Name + ' (' + category.Name + ')').left(80);
		bl.cb5__CBVariable5__c = employeeId;
		bl.cb5__Lock__c = 'Editing';
		bl.CBCategory__c = category.Id;
		bl.cb5__CBAccount__c = category.CBAccount__c;
		bl.cb5__DrillDownIds__c = category.Id;
		blw.budgetLine = bl;

		List<cb5__CBAmount__c> amounts = new List<cb5__CBAmount__c>();
		for (cb5__CBPeriod__c period : periods) amounts.add(new cb5__CBAmount__c(cb5__Value__c = 0, cb5__CBPeriod__c = period.Id));

		if (category.ParentCategory__c != null) {
			cb5__CBNonFinancialLibrary__c resultNFL = resultNFLMap.get(category.Id);
			Decimal allocationRate = category.Allocation__c == null ? 0 : category.Allocation__c;
			List<cb5__CBNonFinancialItem__c> parentResultItems = engagedSourceNFLMap.get(category.NFL1__c).cb5__NonFinancialItems__r;
			for (Integer i = 0; i < resultNFL.cb5__NonFinancialItems__r.size(); i++) {
				amounts[i].cb5__Value__c = (parentResultItems[i].cb5__Value__c * allocationRate / 100).setScale(2);
			}
			blw.amounts = amounts;
			return blw.amounts;
		}

		if (category.NFL1__c == null || category.Formula__c == null) { // category without formula
			cb5__CBNonFinancialLibrary__c resultNFL = resultNFLMap.get(category.Id);
			for (Integer i = 0; i < resultNFL.cb5__NonFinancialItems__r.size(); i++) {
				amounts[i].cb5__Value__c = resultNFL.cb5__NonFinancialItems__r[i].cb5__Value__c;
			}
			blw.amounts = amounts;
			return blw.amounts;
		}

		List<List<cb5__CBNonFinancialItem__c>> sourceNFLItems = new List<List<cb5__CBNonFinancialItem__c>>();
		if (category.NFL1__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL1__c).cb5__NonFinancialItems__r);
		if (category.NFL2__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL2__c).cb5__NonFinancialItems__r);
		if (category.NFL3__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL3__c).cb5__NonFinancialItems__r);
		if (category.NFL4__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL4__c).cb5__NonFinancialItems__r);
		if (category.NFL5__c != null) sourceNFLItems.add(engagedSourceNFLMap.get(category.NFL5__c).cb5__NonFinancialItems__r);

		try {
			blw.amounts = cb5.CBFormulaService.calculateFormulaTotals(amounts, sourceNFLItems, category.Formula__c);
			if (category.TaxThreshold__c != null) {
				CBTaxThresholdProcessor.applyTaxThresholds(blw, category.TaxThreshold__c);
			}
		} catch (Exception e) {
			System.debug('Calculation Error: ' + e);
		}
		return blw.amounts;
	}

	/**
	 * Each category has Result NFL with calculated amounts
	 * This method updates numbers in result NFL and a total value for a category
	 *
	 * @param category processed category
	 * @param calculatedAmounts calculated amounts
	 */
	private static void updateCategoryResult(CBCategory__c category, List<cb5__CBAmount__c> calculatedAmounts) {
		cb5__CBNonFinancialLibrary__c resultNFL = resultNFLMap.get(category.Id);
		category.Value__c = 0;
		for (Integer i = 0; i < calculatedAmounts.size(); i++) {
			resultNFL.cb5__NonFinancialItems__r[i].cb5__Value__c = calculatedAmounts[i].cb5__Value__c;
			category.Value__c += calculatedAmounts[i].cb5__Value__c;
		}
		resultNFL.Name = ('Category Result ' + category.Name).left(80);
		NFLToUpdate.add(resultNFL);
		NFLItemsToUpdate.addAll(resultNFL.cb5__NonFinancialItems__r);
		categoriesToUpdate.add(category);
	}

	/**
	 * Last method to work with the database
	 */
	private static void finalizeDML() {
		delete [SELECT Id FROM cb5__CBBudgetLine__c WHERE CBCategory__c IN:budgetLineIdsToDelete];
		BudgetLineWrapper obj = new BudgetLineWrapper();
		obj.insertBudgetLineWrappers(budgetLineWrappersToInsert);
		obj.assignBLParentChildRelations(budgetLineWrappersToInsert, categories);
		update categoriesToUpdate;
		for (cb5__CBNonFinancialItem__c item : NFLItemsToUpdate) System.debug(item);
		update NFLItemsToUpdate;
		update NFLToUpdate;
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