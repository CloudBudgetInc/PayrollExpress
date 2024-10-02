/**
Copyright (c) 10 2023, AJR
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
import {api, LightningElement, track} from 'lwc';
import {_applyDecStyle, _confirm, _getCopy, _message, _parseServerError} from "c/cbUtils";
import getCategoriesServer from '@salesforce/apex/CBPayrollExpressPageController.getCategoriesServer';
import getNFLServer from '@salesforce/apex/CBPayrollExpressPageController.getNFLServer';
import deleteCategoryServer from '@salesforce/apex/CBPayrollExpressPageController.deleteCategoryServer';
import setAllocatedAndGetChildIndexServer
	from '@salesforce/apex/CBPayrollExpressPageController.setAllocatedAndGetChildIndexServer';
import saveCategoryServer from '@salesforce/apex/CBPayrollExpressPageController.saveCategoryServer';
import saveNFLItemsServer from '@salesforce/apex/CBPayrollExpressPageController.saveNFLItemsServer';
import getRespectiveCategoryAccountServer from '@salesforce/apex/CBPayrollExpressPageController.getRespectiveCategoryAccountServer';
import categoryCanBeDeletedSafelyServer
	from '@salesforce/apex/CBPayrollExpressPageController.categoryCanBeDeletedSafelyServer';
import {calculateResult, calculateTotal, setContext} from "./cbCategoryMath";
import {validateCategory} from "./cbCategoryValidation";

export default class CBCategory extends LightningElement {

	@api recordId;
	@api refreshParent;
	@api styleClass = '';
	@track showSpinner = false;
	@track showNFLSelector = false;
	@track readyToRender = false;
	@track resultDisabled = false;
	@track category;
	@track nflIds = [];
	@track resultNFL = {};
	@track nfls = [];
	CATEGORY_NFL_ORDER = ['cb5p__NFLResult__c', 'cb5p__NFL1__c', 'cb5p__NFL2__c', 'cb5p__NFL3__c', 'cb5p__NFL4__c', 'cb5p__NFL5__c'];

	async connectedCallback() {
		this.showSpinner = true;
		await this.getCategory();
		await this.getNFLs();
		this.showSpinner = false;
		this.readyToRender = true;
		_applyDecStyle();
		this.recalculateResult();
	};

	getCategory = async () => {
		try {
			const params = {categoryId: this.recordId};
			const categories = await getCategoriesServer({params});
			if (categories && categories.length > 0) {
				this.category = categories[0];
				this.nflIds = this.CATEGORY_NFL_ORDER
					.map(field => this.category[field])
					.filter(nflId => nflId);
			}
		} catch (e) {
			_parseServerError('Get Category Error: ', e);
		}
	};

	inputFormats = {
		items: {
			formatter: 'number',
			step: "0.01"
		},
		currency: {
			formatter: 'currency',
			step: "0.01"
		},
		percent: {
			formatter: 'percent',
			step: "0.0001"
		}
	};

	getNFLs = async () => {
		try {
			const params = {nflIds: this.nflIds, budgetYearId: this.category.cb5p__CBBudgetYear__c};
			this.nfls = await getNFLServer(params);
			this.nfls.forEach(n => n.disabled = n.cb5__Type__c !== 'Custom');
			if (this.nfls.length > 1) this.resultDisabled = true;
			this.nfls = this.CATEGORY_NFL_ORDER.reduce((sortedNFLs, f, idx) => {
				const nflId = this.category[f];
				if (nflId) {
					const nfl = this.nfls.find(rec => rec.Id === nflId);
					const format = this.inputFormats[nfl.cb5__Layer__r.cb5__Unit__c];
					console.log('nfl.cb5__Layer__r.cb5__Unit__c : ' + nfl.cb5__Layer__r.cb5__Unit__c);
					console.log('FORMAT : ' + JSON.stringify(format));
					nfl.cb5__NonFinancialItems__r.forEach(item => item.format = format);
					console.log('NFL: ' + JSON.stringify(nfl));
					nfl.idx = `#${idx}`;
					if (f === 'cb5p__NFLResult__c') {
						this.resultNFL = nfl;
					} else {
						sortedNFLs.push(nfl);
					}
				}
				return sortedNFLs;
			}, []);
		} catch (e) {
			_parseServerError('Get NFL Error: ', e);
		}
	};

	recalculateResult = () => {
		setContext(this);
		if (this.nfls?.length > 0) calculateResult();
		calculateTotal();
		this.resultNFL = _getCopy(this.resultNFL);
		this.category = _getCopy(this.category);
	};

	handleAnalyticChange = async (event) => {
		console.log('event.target.name = ' + event.target.name);
		console.log('event.target.value = ' + event.target.value);
		this.category[event.target.name] = event.target.value;
		console.log('this.category = ' + JSON.stringify(this.category));
		if(event.target.name === 'cb5p__Type__c') {
			console.log('IS TYPE New type is ' + this.category.cb5p__Type__c);
			console.log('this.category.cb5p__CBAccount__c before = ' + this.category.cb5p__CBAccount__c);
			this.category.cb5p__CBAccount__c = await getRespectiveCategoryAccountServer({category: this.category});
			this.category = JSON.parse(JSON.stringify(this.category));
			console.log('this.category.cb5p__CBAccount__c after = ' + this.category.cb5p__CBAccount__c);
		}

		await this.saveCategory();
	};

	handleNFLItemChange = (event) => {
		const updatedItem = {
			Id: event.target.name,
			cb5__Value__c: event.target.value
		};
		saveNFLItemsServer({items: [updatedItem]}).catch(e => _parseServerError('Saving NFL Item Error: ', e));
	};

	handleResultItemsChange = async (event) => {
		let item = this.resultNFL.cb5__NonFinancialItems__r.find(item => item.Id === event.target.name);
		item = JSON.parse(JSON.stringify(item));
		item.cb5__Value__c = event.target.value;
		delete item.format;
		saveNFLItemsServer({items: [item]}).catch(e => _parseServerError('Saving Result Item Error: ', e));
	};

	saveCategory = async () => {
		const isNotValid = validateCategory(this.category);
		if (isNotValid) return null;
		await saveCategoryServer({category: this.category})
			.then(categoryId => {
				const needToReload = !this.recordId;
				this.recordId = categoryId;
				if (needToReload) this.connectedCallback().then(r => null);
				_message('success', 'Saved');
			})
			.catch(e => _parseServerError('Saving Category Error: ', e));
	};

	closeDialog = () => {
		this.closeDialogFunction();
	};

	deleteCategory = async () => {
		const canBeDeleted = await categoryCanBeDeletedSafelyServer({categoryId: this.category.Id});
		if (!canBeDeleted) {
			_message('info', 'Category cannot be deleted while its result is being used in other categories.');
			return null;
		}
		const decision = await _confirm('Are you sure to delete the category? Respective budget line will be deleted', 'Confirm', 'warning');
		if (!decision) return null;
		try {
			await deleteCategoryServer({categoryId: this.category.Id});
			_message('success', 'Deleted');
			this.refreshParent();
		} catch (e) {
			_parseServerError('Deleting Error: ', e);
		}
	};

	deleteNFL = async (event) => {
		const NFLIdToDelete = event.target.value;
		let slideUp = false;
		for (let i = 1; i <= 5; i++) {
			const key = `cb5p__NFL${i}__c`;
			const nextKey = `cb5p__NFL${i + 1}__c`;
			if (NFLIdToDelete === this.category[key]) slideUp = true;
			if (slideUp) this.category[key] = this.category[nextKey] ? this.category[nextKey] : null;
		}
		await this.saveCategory();
		this.connectedCallback();
	};

	addNFL = () => {
		for (let i = 1; i <= 5; i++) {
			if (!this.category[`cb5p__NFL${i}__c`]) {
				this.nflWaitToSelect = `cb5p__NFL${i}__c`;
				break;
			}
		}
		if (!this.nflWaitToSelect) return null;
		this.showNFLSelector = true;
	};

	nflWaitToSelect;
	renderNFLSelector = (event) => {
		this.nflWaitToSelect = `cb5p__NFL${event.target.value.replace('#', '')}__c`;
		this.showNFLSelector = true;
	};

	applySelectedNFL = async (result) => {
		this.category[this.nflWaitToSelect] = result;
		this.nflWaitToSelect = undefined;
		this.closeNFLSelector();
		await this.saveCategory();
		this.connectedCallback();
	};

	applyFormulaTemplate = async (event) => {
		this.category.cb5p__Formula__c = event.detail.value;
		await this.saveCategory();
		this.connectedCallback();
	};

	closeNFLSelector = () => {
		this.showNFLSelector = false;
	};

	addChildCategory = async () => {
		const decision = await _confirm('Are you sure to allocate the category?', 'Confirm', 'warning');
		if (!decision) return null;
		const childIndex = await setAllocatedAndGetChildIndexServer({parentCategoryId: this.category.Id}).catch(e => _parseServerError('Get Child Index Error: ', e));
		try {
			const category = {
				Name: 'New',
				cb5p__CBEmployee__c: this.category.cb5p__CBEmployee__c,
				cb5p__CBAccount__c: this.category.cb5p__CBAccount__c,
				cb5p__CBBudgetYear__c: this.category.cb5p__CBBudgetYear__c,
				cb5p__NFL1__c: this.category.cb5p__NFLResult__c,
				cb5p__ParentCategory__c: this.category.Id,
				cb5p__Index__c: childIndex,
				cb5p__Type__c: 'Salary'
			};
			await saveCategoryServer({category})
				.catch(e => _parseServerError('Child Category Saving Error: ', e));
			this.refreshParent();
		} catch (e) {
			_parseServerError('Add Child Category Error: ', e);
		}
	};

}