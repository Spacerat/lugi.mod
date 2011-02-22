
SuperStrict
Import lugi.core
Import brl.standardio

Module lugi.Tablestuff

ModuleInfo "Name: LuGI Table Support Stuff"
ModuleInfo "Description: Support functions for Nilium's disabled-by-default Table thingy."
ModuleInfo "Version: 0.1"
ModuleInfo "Author: Joseph 'spacerat' Atkins-Turkish"
ModuleInfo "License: MIT"
ModuleInfo "URL: <a href=~qhttp://github.com/Spacerat/lugi.mod/~q>http://github.com/Spacerat/lugi.mod/</a>"

Rem
bbdoc: The TLuaFunction object allows you to reference functions and methods which have been defined in Lua, and call them later on.
EndRem
Type TLuaFunction
	Field state:Byte Ptr
	Field ref:Int
	Field freed:Int = False
	
	Rem
	bbdoc: Create a TLuaFunction which references a Lua function at position i on the stack.
	EndRem
	Function Create:TLuaFunction(state:Byte Ptr, i:Int)
		Local n:TLuaFunction = New TLuaFunction
		n.state = state
		If Not lua_type(state, i) = LUA_TFUNCTION Throw "Value at index is not a function."
		lua_pushvalue(state, i)
		n.ref = luaL_ref(state, LUA_REGISTRYINDEX)
		Return n
	End Function
	
	Rem
	bbdoc: Create a TLuafunction which references a lua method of the given obj:name.
	EndRem
	Function CreateFromObject:TLuaFunction(obj:Object, name:String)
		lua_pushbmaxobject(l, obj)
		lua_pushstring(l, name)
		lua_getfenv(l, 1)
		lua_pushvalue(l, 2)
		lua_gettable(l, - 2)
		If lua_type(l, - 1) = LUA_TFUNCTION
			Local ret:TLuaFunction = TLuaFunction.Create(l, - 1)
			lua_settop(l, 0)
			Return ret
		EndIf
	End Function
	
	Rem
	bbdoc: Free the reference in Lua. Called automatically on Delete().
	EndRem
	Method Free()
		If (Not freed) Then luaL_unref(state, LUA_REGISTRYINDEX, ref)
		freed = True
	End Method
	Method Delete()
		Free()
	End Method
	
	Rem
	bbdoc: Call this function, pass some paremeters, get some return values.
	about: If you're calling this as a method, pass "self" as the first parameter.
	EndRem
	Method Call:Object[] (params:Object[] = Null)
		lua_rawgeti(state, LUA_REGISTRYINDEX, ref)
		Return lua_callfunc(state, params)
	End Method
	
	Rem
	bbdoc: A dirty shorcut for sticking this in front of the params array for Call().
	EndRem
	Method CallMethod:Object[] (this:Object, params:Object[] = Null)
		Local args:Object[]
		If params = Null
			args = New Object[1]
			args[0] = this
		Else
			args = New Object[params.Length + 1]
			args[0] = this
			For Local k:Int = 0 To params.Length - 1
				args[k + 1] = params[k]
			Next
		EndIf
		Return Call(args)
	EndMethod
	
End Type

Rem
bbdoc: Fetch and call a Lua method of obj.
EndRem
Function CallLuaMethod:Object[] (l:Byte Ptr, obj:Object, name:String, params:Object[])
	Local ret:Object[]
	lua_pushbmaxobject(l, obj)
	lua_pushstring(l, name)
	lua_getfenv(l, 1)
	lua_pushvalue(l, 2)
	lua_gettable(l, - 2)
	If lua_type(l, - 1) = LUA_TFUNCTION
		
		Local args:Object[]
		If params = Null
			args = New Object[1]
			args[0] = obj
		Else
			args = New Object[params.Length + 1]
			args[0] = obj
			For Local k:Int = 0 To params.Length - 1
				args[k + 1] = params[k]
			Next
		EndIf

		ret = lua_callfunc(l, args)
	EndIf
	lua_settop(l, 0)
	Return ret
EndFunction

Rem
bbdoc: 
EndRem
Function GetLuaField:Object(l:Byte Ptr, obj:Object, name:String)
	Local ret:Object
	lua_pushbmaxobject(l, obj)
	lua_pushstring(l, name)
	lua_getfenv(l, 1)
	lua_pushvalue(l, 2)
	lua_gettable(l, - 2)
	ret = lua_toobject(l, - 1)
	lua_settop(l, 0)
	Return ret
End Function

Rem
bbdoc: Create a TLuaFunction which references a Lua function at position i on the stack.
EndRem
Function lua_tofunction:TLuaFunction(l:Byte Ptr, i:Int)
	Return TLuaFunction.Create(l, i)
End Function

Rem
bbdoc: Convert the value of whatever is at i on the stack to an object.
Numbers become strings, functions become TLuaFunctions. Tables become arrays.
EndRem
Function lua_toobject:Object(l:Byte Ptr, i:Int)
	If (lua_isbmaxobject(l, i)) Then Return lua_tobmaxobject(l, i)
	Select lua_type(l, i)
		Case LUA_TNUMBER, LUA_TSTRING, LUA_TBOOLEAN
			Return lua_tostring(l, i)
		Case LUA_TTABLE
			Return lua_tobmaxarray(l, i)
		Case LUA_TFUNCTION
			Return Object(lua_tofunction(l, i))
		Case LUA_TNIL
			Return Null
		Default
			Throw "Invalid lua type"
	End Select
End Function

rem
bbdoc: Calls the lua function at the top of the stack, pass some paremeters, get some return values.
endrem
Function lua_callfunc:Object[] (l:Byte Ptr, args:Object[] = Null)
	Local prevtop:Int = lua_gettop(l)
	If args = Null
		If lua_pcall(l, 0, LUA_MULTRET, 0) <> 0
			Print "Lua warnning: " + lua_tostring(L, - 1)
		End If
	Else
		Local nargs:Int = 0
		For Local arg:Object = EachIn args
			Local num:Double = Double(String(arg))
			If num <> Null
				lua_pushnumber(l, num)
			Else
				lua_pushbmaxobject(l, arg)
			EndIf
			nargs:+1
		Next
		If lua_pcall(l, nargs, LUA_MULTRET, 0) <> 0
			Print "Lua warnning: " + lua_tostring(L, - 1)
		End If
	EndIf
	If lua_gettop(l) = 1
		Return Null
	EndIf
	
	Local top:Int = lua_gettop(l)
	Local returns:Object[] = New Object[top - prevtop + 1]
	
	For Local i:Int = (prevtop) To top
		returns[i - prevtop] = lua_toobject(l, i)
	Next
	lua_pop(l, top - prevtop + 1)
	Return returns
End Function
