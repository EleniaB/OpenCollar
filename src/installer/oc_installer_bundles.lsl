//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//              ____                   ______      ____                     //
//             / __ \____  ___  ____  / ____/___  / / /___ ______           //
//            / / / / __ \/ _ \/ __ \/ /   / __ \/ / / __ `/ ___/           //
//           / /_/ / /_/ /  __/ / / / /___/ /_/ / / / /_/ / /               //
//           \____/ .___/\___/_/ /_/\____/\____/_/_/\__,_/_/                //
//               /_/                                                        //
//                                                                          //
//                        ,^~~~-.         .-~~~"-.                          //
//                       :  .--. \       /  .--.  \                         //
//                       : (    .-`<^~~~-: :    )  :                        //
//                       `. `-,~            ^- '  .'                        //
//                         `-:                ,.-~                          //
//                          .'                  `.                          //
//                         ,'   @   @            |                          //
//                         :    __               ;                          //
//                      ...{   (__)          ,----.                         //
//                     /   `.              ,' ,--. `.                       //
//                    |      `.,___   ,      :    : :                       //
//                    |     .'    ~~~~       \    / :                       //
//                     \.. /               `. `--' .'                       //
//                        |                  ~----~                         //
//                        | script - YYMMDD.n   |                           //
// ------------------------------------------------------------------------ //
//  This script is free software: you can redistribute it and/or modify     //
//  it under the terms of the GNU General Public License as published       //
//  by the Free Software Foundation, version 2.                             //
//                                                                          //
//  This script is distributed in the hope that it will be useful,          //
//  but WITHOUT ANY WARRANTY; without even the implied warranty of          //
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the            //
//  GNU General Public License for more details.                            //
//                                                                          //
//  You should have received a copy of the GNU General Public License       //
//  along with this script; if not, see www.gnu.org/licenses/gpl-2.0        //
// ------------------------------------------------------------------------ //
//  This script and any derivatives based on it must remain "full perms".   //
//                                                                          //
//  "Full perms" means maintaining MODIFY, COPY, and TRANSFER permissions   //
//  in Second Life(R), OpenSimulator and the Metaverse.                     //
//                                                                          //
//  If these platforms should allow more fine-grained permissions in the    //
//  future, then "full perms" will mean the most permissive possible set    //
//  of permissions allowed by the platform.                                 //
// ------------------------------------------------------------------------ //
//  Copyright (C) 2008 - 2015:    Individual Contributors                   //
//                                OpenCollar - submission set free(TM)      //
//                                and Virtual Disgrace(TM)                  //
// ------------------------------------------------------------------------ //
//  Source Code Repository:       github.com/OpenCollar/OC                  //
// ------------------------------------------------------------------------ //
//////////////////////////////////////////////////////////////////////////////

// this script receives DO_BUNDLE messages that contain the uuid of the collar being updated, 
// the name of a bundle notecard, the talkchannel on which the collar shim script is listening, and
// the script pin set by the shim.  This script then loops over the items listed in the notecard
// and chats with the shim about each one.  Items that are already present (as determined by uuid) 
// are skipped.  Items not present are given to the collar.  Items that are present but don't have the
// right uuid are deleted and replaced with the version in the updater.  Scripts are loaded with 
// llRemoteLoadScriptPin, and are set running immediately.

// once the end of the notecard is reached, this script sends a BUNDLE_DONE message that includes all the same 
// stuff it got in DO_BUNDLE (talkchannel, recipient, card, pin).

integer DO_BUNDLE = 98749;
integer BUNDLE_DONE = 98750;

integer talkchannel;
key rcpt;
string card;
integer pin;
string mode;

integer line;
key lineid;
integer listener;

SetStatus(string name) {
    // use card name, item type, and item name to set a nice 
    // text status message
    list cardparts = llParseString2List(card, ["_"], []);
    string bundle = llList2String(cardparts, 2);
    string msg = llDumpList2String([
        "Doing Bundle: " + bundle,
        "Doing Item: " + name
    ], "\n");
    llSetText(msg, <1,1,1>, 1.0);
}

debug(string msg) {
    //llOwnerSay(llGetScriptName() + ": " + msg);
}

default
{   
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == DO_BUNDLE)
        {
            debug("doing bundle: " + str);
            // str will be in form talkchannel|uuid|bundle_card_name
            list parts = llParseString2List(str, ["|"], []);
            talkchannel = (integer)llList2String(parts, 0);
            rcpt = (key)llList2String(parts, 1);
            card = llList2String(parts, 2);
            pin = (integer)llList2String(parts, 3);
            mode = llList2String(parts, 4); // either INSTALL or REMOVE
            line = 0;
            llListenRemove(listener);
            listener = llListen(talkchannel, "", rcpt, "");
            
            // get the first line of the card
            lineid = llGetNotecardLine(card, line);
        }
    }
    
    dataserver(key id, string data)
    {
        if (id == lineid)
        {
            if (data != EOF)
            {
                // process bundle line
                list parts = llParseString2List(data, ["|"], []);
                string type = llList2String(parts, 0);
                string name = llList2String(parts, 1);
                key uuid;
                string msg;
                
                SetStatus(name);
                
                uuid = llGetInventoryKey(name);
                msg = llDumpList2String([type, name, uuid, mode], "|");
                debug("querying: " + msg);             
                llRegionSayTo(rcpt, talkchannel, msg);
            }
            else
            {
                debug("finished bundle: " + card);
                // all done reading the card. send link msg to main script saying we're done.
                llListenRemove(listener);
                llSetText("", <1,1,1>, 1.0);
                llMessageLinked(LINK_SET, BUNDLE_DONE, llDumpList2String([talkchannel, rcpt, card, pin, mode], "|"), "");
            }
        }
    }
    
    listen(integer channel, string name, key id, string msg)
    {
        debug("heard: " + msg);
        // let's live on the edge and assume that we only ever listen with a uuid filter so we know it's safe
        // look for msgs in the form <type>|<name>|<cmd>
        list parts = llParseString2List(msg, ["|"], []);
        if (llGetListLength(parts) == 3)
        {
            string type = llList2String(parts, 0);
            string name = llList2String(parts, 1);
            string cmd = llList2String(parts, 2);            
            if (cmd == "SKIP" || cmd == "OK")
            {
                // move on to the next item by reading the next notecard line
                line++;
                lineid = llGetNotecardLine(card, line);
            }
            else if (cmd == "GIVE")
            {
                // give the item, and then read the next notecard line.
                if (type == "ITEM")
                {
                    llGiveInventory(id, name);
                }
                else if (type == "SCRIPT")
                {
                    // get the full name, and load it via script pin.
                    llRemoteLoadScriptPin(id, name, pin, TRUE, 0);
                }
                line++;
                lineid = llGetNotecardLine(card, line);
            }
        }
    }
    
    on_rez(integer num)
    {
        llResetScript();
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            llResetScript();
        }
    }
}
