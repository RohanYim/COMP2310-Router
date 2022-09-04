--
--  Framework: Uwe R. Zimmer, Australia, 2015
--

with Ada.Strings.Bounded;           use Ada.Strings.Bounded;
with Generic_Routers_Configuration;

generic
   with package Routers_Configuration is new Generic_Routers_Configuration (<>);

package Generic_Message_Structures is

   use Routers_Configuration;

   package Message_Strings is new Generic_Bounded_Length (Max => 80);
   use Message_Strings;

   subtype The_Core_Message is Bounded_String;

   type Messages_Client is record
      Destination : Router_Range;
      The_Message : The_Core_Message;
   end record;

   type Messages_Mailbox is record
      Sender      : Router_Range     := Router_Range'Invalid_Value;
      The_Message : The_Core_Message := Message_Strings.To_Bounded_String ("");
      Hop_Counter : Natural          := 0;
   end record;

   -- Leave anything above this line as it will be used by the testing framework
   -- to communicate with your router.

   --  Add one or multiple more messages formats here ..

   -- local table to store Dijkstra array S
   type Element_S is record
      Next        : Router_Range := Router_Range'Invalid_Value;
      Dis       : Natural      := 10000;
   end record;
   type Local_Table_S is array (Router_Range) of Element_S;

   type Messages_Table is record
      Sender             : Router_Range     := Router_Range'Invalid_Value;
      Table : Local_Table_S;
   end record;

   type Messages_R is record
      Sender      : Router_Range     := Router_Range'Invalid_Value;
      Destination : Router_Range     := Router_Range'Invalid_Value;
      The_Message : The_Core_Message := Message_Strings.To_Bounded_String ("");
      Hop_Counter : Natural          := Natural'Invalid_Value;
   end record;


end Generic_Message_Structures;
