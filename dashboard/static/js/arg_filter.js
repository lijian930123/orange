(function (L) {
    var _this = null;
    L.ArgFilter = L.ArgFilter || {};
    _this = L.ArgFilter = {
        data: {
        },

        init: function () {
            L.Common.loadConfigs("arg_filter", _this, true);
            _this.initEvents();
        },

        initEvents: function(){
            var op_type = "arg_filter";
            L.Common.initRuleAddDialog(op_type, _this);//添加规则对话框
            L.Common.initRuleDeleteDialog(op_type, _this);//删除规则对话框
            L.Common.initRuleEditDialog(op_type, _this);//编辑规则对话框
            L.Common.initRuleSortEvent(op_type, _this);

            L.Common.initSelectorAddDialog(op_type, _this);
            L.Common.initSelectorDeleteDialog(op_type, _this);
            L.Common.initSelectorEditDialog(op_type, _this);
            L.Common.initSelectorSortEvent(op_type, _this);
            L.Common.initSelectorClickEvent(op_type, _this);

            L.Common.initSelectorTypeChangeEvent();//选择器类型选择事件
            L.Common.initConditionAddOrRemove();//添加或删除条件
            L.Common.initJudgeTypeChangeEvent();//judge类型选择事件
            L.Common.initConditionTypeChangeEvent();//condition类型选择事件

            L.Common.initViewAndDownloadEvent(op_type, _this);
            L.Common.initSwitchBtn(op_type, _this);//redirect关闭、开启
            L.Common.initSyncDialog(op_type, _this);//编辑规则对话框
        },

        buildRule: function(){
            var result = {
                success: false,
                data: {
                    name: null,
                    judge:{},
                    handle:{},
                    source:null,
                    target:null
                }
            };

            //build name and judge
            var buildJudgeResult = L.Common.buildJudge();
            if(buildJudgeResult.success == true){
                result.data.name = buildJudgeResult.data.name;
                result.data.judge = buildJudgeResult.data.judge;
            }else{
                result.success = false;
                result.data = buildJudgeResult.data;
                return result;
            }

            //build handle
            var buildHandleResult = _this.buildHandle();
            if(buildHandleResult.success == true){
                result.data.handle = buildHandleResult.handle;
            }else{
                result.success = false;
                result.data = buildHandleResult.data;
                return result;
            }

            var source = $("#rule-source").val();
            /*if (!source) {
                result.data = "被替换文本不能为空";
                return result;
            }*/
            result.data.source = source;

            var target = $("#rule-target").val();
            /*if (!target) {
                result.data = "替换文本不能为空";
                return result;
            }*/
            result.data.target = target;

            //enable or not
            var enable = $('#rule-enable').is(':checked');
            result.data.enable = enable;

            result.success = true;
            return result;
        },

        buildHandle: function(){
            var result = {};
            var handle = {};
            handle.continue = ($("#rule-handle-continue").val() === "true");
            handle.log = ($("#rule-handle-log").val() === "true");
            result.success = true;
            result.handle = handle;
            return result;
        }
    };
}(APP));
