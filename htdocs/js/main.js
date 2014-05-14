var __util = {
    time_handle: null,
    last_aps_info: {},
    token_str: '',
    nl2br: function(str, is_xhtml) {
        var breakTag = (is_xhtml || typeof is_xhtml === 'undefined') ? '<br />' : '<br>';
        return (str + '').replace(/([^>\r\n]?)(\r\n|\n\r|\r|\n)/g, '$1'+ breakTag +'$2');
    },
    action_start_pins: function() {
        $('._table_result tbody').html('');
        $('._get_pin_aps').attr('disabled', 'disabled');
        $('._loading').show();
        __util.get_result();
        //停止按钮
        $('._stop_get_pin_aps').removeClass('hide');
        $('._pin_aps').addClass('hide');
    },
    get_param: function(param) {
        return $.extend({token_str: __util.token_str}, param);
    },
    get_pins_ap_list: function() {
        __util.last_aps_info = {};
        $.getJSON('/util?act=start_get_pin', __util.get_param({}), function(data) {
            if (data.errcode == 0) {
                __util.action_start_pins();
            } else {
                if (data.errcode == 10) {
                    //提示是否要强制重新开始
                    if (confirm('当前可能有正在执行的扫描进程,是否强制结束重新开始?')) {
                        $.getJSON('/util?act=force_auto_pin', __util.get_param({}), function() {
                            __util.action_start_pins();
                        });
                    }
                } else {
                    alert(data.msg);
                }
            }
        });
    },
    render_html: function(data) {
        var $t_result = $('._table_result tbody'),
            html = '';
        for (var i = 0,l = data.data_list.length; i < l; i++) {
            var render_data = {
                data: data.data_list[i]
            }
            html = template.render('reaver_item', render_data);
            $t_result.append(html);
        }
    },
    post_get_result: function() {
        $('._get_pin_aps').removeAttr('disabled');
        $('._loading').hide();
        $('._stop_get_pin_aps').addClass('hide');
        //破解pin按钮
        $('._pin_aps').removeClass('hide');
        if (__util.time_handle) {
            clearTimeout(__util.time_handle);
            __util.time_handle = null;
        }
    },
    insert_to_last_ap_info: function(data) {
        for (var i = 0, j = data.data_list.length; i < j; i++){
            __util.last_aps_info[data_list[i][0]] = data_list[i];
        }
    },
    get_result: function() {
        __util.time_handle = setTimeout(function() {
            $.getJSON('/util?act=get_result', __util.get_param({}), function(data) {
            if (data.errcode == 0) {
                __util.render_html(data);
                __util.get_result();
            } else if(data.errcode == 1) {
                __util.render_html(data);
                __util.post_get_result()
            }
            sorttable.makeSortable($('._table_result')[0]);
        });
        }, 2000);
    },
    click_result_row: function() {
        var $this = $(this);
        if ($this.hasClass('highlight')) {
            $this.removeClass('highlight').find('td._mac_addr').removeClass('_td_hightlight');
        } else {
            $this.addClass('highlight').siblings('tr').removeClass('highlight').find('td._mac_addr').removeClass('_td_highlight');
            $this.find('td._mac_addr').addClass('_td_highlight');
        }
    },
    stop_get_pins: function() {
        $.getJSON('/util?act=force_stop_auto_pin', __util.get_param({}), function(data) {
            if (data.errcode == 0) {
                __util.post_get_result();
            }
        })
    },
    switch_containter: function(type) {
        if (type == 'get_pin_aps') {
            //扫描的界面
            $('._get_pin_aps_container').removeClass('hide');
            $('._pin_aps_container').addClass('hide');
        } else if(type == 'pin_aps') {
            //破解的界面
            $('._get_pin_aps_container').addClass('hide');
            $('._pin_aps_container').removeClass('hide');
        }
    },
    pin_aps: function() {
        var $table = $('._table_result'),
            mac_addr = [];
        $table.find('._mac_addr._td_highlight').each(function() {
            mac_addr.push($(this).text());
        });
        $.getJSON('/util?act=pin_aps', __util.get_param({mac_addr: mac_addr.join(' ')}), function(data) {
            if (data.errcode == 0) {
                if (__util.time_handle) {
                    clearTimeout(__util.time_handle);
                }
                __util.switch_containter('pin_aps');
                __util.time_handle = setTimeout(__util.get_pin_aps_result, 2000);
                __util.toggle_pin_aps_pannel('show');
            }
        })
    },
    toggle_pin_aps_pannel: function(type) {
        if (type == 'show') {
            $('._pin_aps_pannel ._pin_aps').addClass('hide');
            $('._pin_aps_pannel ._stop_pin_aps').removeClass('hide');
        } else {
            $('._pin_aps_pannel ._pin_aps').removeClass('hide');
            $('._pin_aps_pannel ._stop_pin_aps').addClass('hide');
        }
    },
    stop_pin_aps: function() {
        $.getJSON('/util?act=stop_pin_aps', __util.get_param({}), function(data) {
            if (data.errcode == 0) {
                if (__util.time_handle) {
                    clearTimeout(__util.time_handle);
                }
                __util.toggle_pin_aps_pannel('hide');
            }
        });
    },
    get_pin_aps_result: function() {
        $.getJSON('/util?act=pin_aps_result', __util.get_param({}), function(data) {
            if (data.errcode == 0) {
                if (data.extra_data && data.extra_data.current_pin_bssid) {
                    $('._current_pin_aps_mac').text(data.extra_data.current_pin_bssid);
                    if (__util.last_aps_info[data.current_pin_aps_mac]) {
                        $('._current_pin_aps_essid').text(__util.last_aps_info[data.current_pin_aps_mac][5]);
                    }
                }

                var $t = $('._pins_result_text');
                if (data.data_list.length) {
                    $t.val(data.data_list.join('\n') + '\n' + $t.val());
                }
                __util.time_handle = setTimeout(__util.get_pin_aps_result, 2000);
            }
        });
    },
    get_token: function() {
        var uuid = ''; 
        for (var i = 0; i < 32; i++) {
            uuid += Math.floor(Math.random() * 16).toString(16);
        }   
        return uuid;
    },
    init_status: function() {
        var token_str = __util.get_token();
        __util.token_str = token_str;
        $.getJSON('/util?act=set_token', {token_str: token_str}, function() {
            $.getJSON('/util?act=get_status', __util.get_param({}), function(data) {
                if (data.errcode == 0) {
                    //是否正在扫描
                    if (data.data_list.current_reaver_pid || data.data_list.current_reaver_sh_pid) {
                        $('._init_status_confirm').removeClass('hide').siblings('._container').addClass('hide');
                    }
                }
            });
        });

        
    },
    reset_all: function() {
        $.getJSON('/util?act=reset_all', __util.get_param({}), function() {
            location.reload();
        });
    },
    show_pin_aps_status: function() {
        $(this).parent('div._container').addClass('hide')
        __util.switch_containter('pin_aps');
        __util.time_handle = setTimeout(__util.get_pin_aps_result, 2000);
        __util.toggle_pin_aps_pannel('show');        
    }
    
}

$(function() {
    $(document)
    //扫描开启wps的路由器
    .on('click', '._get_pin_aps', __util.get_pins_ap_list)
    //扫描出来结果以后,点击每一行的行为
    .on('click', '._result_row', __util.click_result_row)
    //停止扫描
    .on('click', '._stop_get_pin_aps', __util.stop_get_pins)
    //开启破解
    .on('click', '._pin_aps', __util.pin_aps)
    //停止破解
    .on('click', '._stop_pin_aps', __util.stop_pin_aps)
    .on('click', '._show_pin_container', __util.show_pin_aps_status)
    //重置所有的状态
    .on('click', '._reset_all', __util.reset_all);
    
    __util.init_status();
});
