local function get_shop_formspec(pos, p)
	local meta = minetest.get_meta(pos)
	local spos = pos.x.. "," ..pos.y .. "," .. pos.z
	local formspec =
		"size[8,7]" ..
		default.gui_bg ..
		default.gui_bg_img ..
		default.gui_slots ..
		"label[0,1;Item]" ..
		"label[3,1;Cost]" ..
		"button[0,0;2,1;ok;Buy]" ..
		"button_exit[3,0;2,1;exit;Exit]" ..
		"button[6,0;2,1;stock;Stock]" ..
		"button[6,1;2,1;register;Register]" ..
		"button[0,2;1,1;prev;<]" ..
		"button[1,2;1,1;next;>]" ..
		"list[nodemeta:" .. spos .. ";sell" .. p .. ";1,1;1,1;]" ..
		"list[nodemeta:" .. spos .. ";buy" .. p .. ";4,1;1,1;]" ..
		"list[current_player;main;0,3.25;8,4;]"
	return formspec
end

local formspec_register =
	"size[8,9]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;Register]" ..
	"list[current_name;register;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

local formspec_stock =
	"size[8,9]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;Stock]" ..
	"list[current_name;stock;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

minetest.register_privilege("shop_admin", "Shop administration and maintainence")

minetest.register_node("shop:shop", {
	description = "Shop",
	tiles = {
		"shop_shop_topbottom.png",
		"shop_shop_topbottom.png",
		"shop_shop_side.png",
		"shop_shop_side.png",
		"shop_shop_side.png",
		"shop_shop_front.png",
	},
	groups = {choppy = 3, oddly_breakable_by_hand = 1},
	paramtype2 = "facedir",
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		meta:set_string("pos", pos.x .. "," .. pos.y .. "," .. pos.z)
		local owner = placer:get_player_name()

		meta:set_string("owner", owner)
		meta:set_string("infotext", "Shop (Owned by " .. owner .. ")")
		meta:set_string("formspec", get_shop_formspec(pos, 1))
		meta:set_int("pages_current", 1)
		meta:set_int("pages_total", 1)

		local inv = meta:get_inventory()
		inv:set_size("buy1", 1)
		inv:set_size("sell1", 1)
		inv:set_size("stock", 8*4)
		inv:set_size("register", 8*4)
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		local node_pos = minetest.string_to_pos(meta:get_string("pos"))
		local owner = meta:get_string("owner")
		local inv = meta:get_inventory()
		local pg_current = meta:get_int("pages_current")
		local pg_total = meta:get_int("pages_total")
		local s = inv:get_list("sell" .. pg_current)
		local b = inv:get_list("buy" .. pg_current)
		local stk = inv:get_list("stock")
		local reg = inv:get_list("register")
		local player = sender:get_player_name()
		local pinv = sender:get_inventory()

		if fields.next then
			print("It was next.")
			if pg_total < 32 and
					pg_current == pg_total and
					player == owner and
					not (inv:is_empty("sell" .. pg_current) or inv:is_empty("buy" .. pg_current)) then
				inv:set_size("buy" .. pg_current + 1, 1)
				inv:set_size("sell" .. pg_current + 1, 1)
				meta:set_string("formspec", get_shop_formspec(node_pos, pg_current + 1))
				meta:set_int("pages_current", pg_current + 1) 
				meta:set_int("pages_total", pg_current + 1)
			elseif pg_total > 1 then
				if pg_current < pg_total then
					meta:set_int("pages_current", pg_current + 1)
				else
					meta:set_int("pages_current", 1)
				end
				meta:set_string("formspec", get_shop_formspec(node_pos, meta:get_int("pages_current")))
			end
		elseif fields.prev then
			print("It was prev.")
			if pg_current == 1 and pg_total > 1 then
				meta:set_int("pages_current", pg_total)
			elseif pg_current > 1 then
				meta:set_int("pages_current", pg_current - 1)
			end
			meta:set_string("formspec", get_shop_formspec(node_pos, meta:get_int("pages_current")))
		elseif fields.register then
			if player ~= owner and (not minetest.check_player_privs(player, "shop_admin")) then
				minetest.chat_send_player(player, "Only the shop owner can open the register.")
				return
			else
				minetest.show_formspec(player, "shop:shop", formspec_register)
			end
		elseif fields.stock then
			if player ~= owner and (not minetest.check_player_privs(player, "shop_admin")) then
				minetest.chat_send_player(player, "Only the shop owner can open the stock.")
				return
			else
				minetest.show_formspec(player, "shop:shop", formspec_stock)
			end
		elseif fields.ok then
			if inv:is_empty("sell" .. pg_current) or
			    inv:is_empty("buy" .. pg_current) or
			    (not inv:room_for_item("register", b[1])) then
				minetest.chat_send_player(player, "Shop closed.")
				return
			end

			if (pinv:contains_item("main", b[1]) or
					pinv:contains_item("funds", b[1])) and --?
					inv:contains_item("stock", s[1]) and
					pinv:room_for_item("main", s[1]) then
				pinv:remove_item("main", b[1])
				inv:add_item("register", b[1])
				inv:remove_item("stock", s[1])
				pinv:add_item("main", s[1])
			else
				print("exception")
				if not inv:contains_item("stock", s[1]) then
					print("-> no stock?")
					minetest.chat_send_player(player, "Out of stock!")
				end
				if not pinv:contains_item("main", b[1]) then
					print("-> no funds?")
					minetest.chat_send_player(player, "Not enough credits!")
				end
			end
		end
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local inv = meta:get_inventory()
		local pg_current = meta:get_string("pages_current")
		local s = inv:get_list("sell" .. pg_current)
		local n = stack:get_name()
		local playername = player:get_player_name()
		if playername ~= owner and
		    (not minetest.check_player_privs(playername, "shop_admin")) then
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local playername = player:get_player_name()
		if playername ~= owner and
		    (not minetest.check_player_privs(playername, "shop_admin"))then
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local playername = player:get_player_name()
		if playername ~= owner and
		    (not minetest.check_player_privs(playername, "shop_admin")) then
			return 0
		else
			return count
		end
	end,
	can_dig = function(pos, player) 
                local meta = minetest.get_meta(pos) 
                local owner = meta:get_string("owner") 
                local inv = meta:get_inventory() 
                return player:get_player_name() == owner and
		    inv:is_empty("register") and
		    inv:is_empty("stock") and
		    -- FIXME Make all contents in the buy/sell lists drop as items.
		    inv:is_empty("buy1") and
		    inv:is_empty("sell1")
	end,

})

minetest.register_craftitem("shop:coin", {

	description = "Gold Coin",
	inventory_image = "shop_coin.png",
})

minetest.register_craft({
	output = "shop:coin 9",
	recipe = {
		{"default:gold_ingot"},
	}
})

minetest.register_craft({
	output = "default:gold_ingot",
	recipe = {
		{"shop:coin", "shop:coin", "shop:coin"},
		{"shop:coin", "shop:coin", "shop:coin"},
		{"shop:coin", "shop:coin", "shop:coin"}
	}
})

minetest.register_craft({
	output = "shop:shop",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "default:gold_ingot", "group:wood"},
		{"group:wood", "group:wood", "group:wood"}
	}
})
