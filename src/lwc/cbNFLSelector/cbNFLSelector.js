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
import {_applyDecStyle, _parseServerError} from "c/cbUtils";
import getRecentNFLsServer from '@salesforce/apex/CBPayrollExpressPageController.getRecentNFLsServer';
import getNFLServer from '@salesforce/apex/CBPayrollExpressPageController.getNFLServer';
import createNewNFLServer from '@salesforce/apex/CBPayrollExpressPageController.createNewNFLServer';

export default class CBNFLSelector extends LightningElement {

	@api budgetYearId;
	@api employeeId;
	@api closeDialogFunction;
	@api applySelectedFunction;
	@track showSpinner = false;
	@track showCategories = false;
	@track readyToRender = false;
	@track recentNFLs = [];
	@track NFLHint = {};
	@track showNFLHint = false;

	async connectedCallback() {
		this.readyToRender = false;
		this.showSpinner = true;
		await this.getRecentNFLs();
		this.showSpinner = false;
		this.readyToRender = true;
		_applyDecStyle();
	};

	getRecentNFLs = async () => {
		try {
			this.recentNFLs = await getRecentNFLsServer({employeeId: this.employeeId, budgetYearId: this.budgetYearId});
		} catch (e) {
			_parseServerError('Get Employee Error: ', e);
		}
	};

	renderNFLHint = async (event) => {
		try {
			this.showNFLHint = false;
			const selectedNFLId = event.target.id.slice(0, 15);
			this.NFLHint = await getNFLServer({nflIds: [selectedNFLId], budgetYearId: this.budgetYearId});
			this.NFLHint = this.NFLHint[0];
			this.showNFLHint = true;
		} catch (e) {
			_parseServerError('Get Hint Error ', e);
		}
	};

	hideNFLHint = () => {
		this.showNFLHint = false;
	};

	closeDialog = () => {
		this.closeDialogFunction();
	};

	handleSearchedNFL = (event) => {
		this.apply(event.target.value);
	};

	handleLayerSelection = async (event) => {
		const selectedNFLId = await createNewNFLServer({layerId: event.target.value}).catch(e => _parseServerError('Creating Error : ', e));
		this.apply(selectedNFLId);
	};

	applyRecentNFL = (event) => {
		const selectedNFLId = event.target.id.slice(0, 15);
		this.apply(selectedNFLId);
	};

	apply = (selectedId) => {
		this.applySelectedFunction(selectedId);
	}
}