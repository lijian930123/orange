(function (L) {
    var _this = null;
    L.GlobalMonitor = L.GlobalMonitor || {};
    _this = L.GlobalMonitor = {
        data: {
            page: 1,
            size: 10,
            rule_id: '',
            order_type: 'time', // time or count
            sort_type: 'down', // up or down
        },

        init: function () {
            _this.loadConfigs("global_monitor", _this, true);
            L.Common.initSwitchBtn("global_monitor", _this);//global_monitor关闭、开启
            _this.loadRules();
            _this.initTableRowEvent();
            _this.initCloseBtnEvent();
            _this.initSearchBtnEvent();
            _this.initInputEvent();
        },

        loadConfigs: function (type, context, page_load, callback) {
            var op_type = type;
            $.ajax({
                url: '/' + op_type + '/selectors',
                type: 'get',
                cache: false,
                data: {},
                dataType: 'json',
                success: function (result) {
                    if (result.success) {
                        L.Common.resetSwitchBtn(result.data.enable, op_type);
                        $("#switch-btn").show();
                        callback && callback();
                    } else {
                        _this.showErrorTip("错误提示", "查询" + op_type + "配置请求发生错误");
                    }
                },
                error: function () {
                    _this.showErrorTip("提示", "查询" + op_type + "配置请求发生异常");
                }
            });
        },

        loadRules: function () {
            var rule_id = _this.data.rule_id
            var page = _this.data.page
            var size = _this.data.size
            var order_type = _this.data.order_type
            var sort_type = _this.data.sort_type
            $.ajax({
                url: '/global_monitor/list?rule_id=' + rule_id + '&page='+page+'&size='+size + '&order_type=' + order_type + '&sort_type=' + sort_type,
                type: 'get',
                cache: false,
                data: {},
                dataType: 'json',
                success: function (result) {
                    if (result.success) {
                        _this.renderRules(result.data);
                        _this.initPagination(result.totalPage)
                    } else {
                        L.Common.showErrorTip("错误提示", "查询数据发生错误");
                    }
                },
                error: function () {
                    L.Common.showErrorTip("提示", "查询数据发生异常");
                }
            });
        },
        // 初始化分页
        initPagination: function (totalPage) {
            window.pagObj = $('#pagination').twbsPagination({
                totalPages: totalPage,
                visiblePages: 5,
                onPageClick: function (event, page) {
                    if (page === _this.data.page) {
                        return
                    }
                    _this.data.page = page
                    _this.loadRules();
                }
            })
        },

        renderRules: function (data) {
            data = data || {};
            if(!data.rules || data.rules.length<1){
                var html = '<div class="alert alert-warning" style="margin: 25px 0 10px 0;">'+
                        '<p>该选择器下没有规则,请添加!</p>'+
                '</div>';
                $("#rules").html(html);
            }else{
                var tpl = $("#rule-item-tpl").html();
                var html = juicer(tpl, data);
                $("#rules").html(html);
            }
        },

        initTableRowEvent: function () {
            var pageX = 0;
            var pageY = 0;

            $(document).on( "mousedown",".global-monitor .rule-row-tr", function(e){
                pageX = e.pageX
                pageY = e.pageY
            });

            $(document).on( "mouseup",".global-monitor .rule-row-tr", function(e){
                // js模拟click事件，以防选择文本时触发click事件
                if (pageX === e.pageX && pageY === e.pageY) {
                    var self = $(this);
                    var statisticBtn = self.find('.statistic-btn')
                    var rule_id = statisticBtn.attr("data-id");
                    var rule_name = statisticBtn.attr("data-name");
                    if(!rule_id){
                        return;
                    }
                    $('.global-monitor .rule-row-tr.selected').removeClass('selected')
                    self.addClass('selected')
                    $('#iframe-wrapper').removeClass('hide')
                    $('#iframe-wrapper .uri-wrapper').text(rule_id)
                    $('#iframe-wrapper iframe').attr('src', "/monitor/rule/statistic?rule_id="+rule_id+"&monitor_type=global")
                }
            });
        },

        initCloseBtnEvent: function(){
            $(document).on("click", "#iframe-wrapper .close-btn", function () {
                $('.global-monitor .rule-row-tr.selected').removeClass('selected')
                $('#iframe-wrapper').addClass('hide')
                $('#iframe-wrapper iframe').attr('src', "")
            })
        },

        initInputEvent: function () {
            $('#selector-name').keyup(function(event){
                if(event.keyCode ==13){
                  $("#search-btn").trigger("click");
                }
            });
        },

        initSearchBtnEvent:function(){
            $(document).on( "click","#search-btn", function(){
                _this.data.rule_id = $("#selector-name").val();
                _this.loadRules()
            });

            $('.totalCount [name="bootstrap-switch"]').bootstrapSwitch({
                size: 'small',
                onSwitchChange: function (e, value) {
                    _this.data.order_type = 'count'
                    _this.data.sort_type = value ? 'up' : 'down'
                    _this.loadRules()
                }
            });
            $('.averageRequestTime [name="bootstrap-switch"]').bootstrapSwitch({
                size: 'small',
                onSwitchChange: function (e, value) {
                    _this.data.order_type = 'time'
                    _this.data.sort_type = value ? 'up' : 'down'
                    _this.loadRules()
                }
            });
        }
    };
}(APP));
