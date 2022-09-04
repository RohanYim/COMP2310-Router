--
--  Framework: Uwe R. Zimmer, Australia, 2019
--

with Exceptions; use Exceptions;
with Queue_Pack_Protected_Generic;
with Ada.Text_IO;          use Ada.Text_IO;

package body Generic_Router is

   task body Router_Task is

      Connected_Routers : Ids_To_Links;


   begin
      accept Configure (Links : Ids_To_Links) do
         Connected_Routers := Links;
      end Configure;

      declare
         Port_List : constant Connected_Router_Ports := To_Router_Ports (Task_Id, Connected_Routers);
          -- Declare Local Table
         Local_Table : Local_Table_S;
         Passing_Message : Messages_R;
         Find_Route_Message :Messages_Table;
         Is_Updated : Boolean := False;
         Is_Shutdown                : Boolean := False;
         -- Queues
         type Queue_Size is mod 1000;
         package Mailbox_Queue is new Queue_Pack_Protected_Generic (Messages_Mailbox, Queue_Size);
         package Waiting_Queue is new Queue_Pack_Protected_Generic (Messages_R, Queue_Size);
         MailboxQueue : Mailbox_Queue.Protected_Queue;
         WaitingQueue : Waiting_Queue.Protected_Queue;
         -- Local message
         Local_Message : Messages_R;
         Mailbox_Message : Messages_Mailbox;

      begin


--           for i of Local_Table loop
--              if i.Dis = 1 then
--                 Put_Line (Task_Id'Image & "has neighbor " & i.Next'Image);
--              end if;
--           end loop;



         declare
            task Init is
               entry Start;
            end Init;
--              task Message_Check is
--                 entry Check;
--              end Message_Check;

            task Update is
               entry Send;
               entry Close_Sender;
            end Update;


            task body Init is
               Initial_Message : Messages_Table;
            begin
               accept Start;
               if Task_Id = Router_Range'First then
                  Initial_Message.Sender := Task_Id;
                  Initial_Message.Table := Local_Table;
                  for element of Port_List loop
                     element.Link.all.Find_Route(Initial_Message);
                  end loop;
               end if;
            end Init;
--              task body Message_Check is
--              begin
--                 select
--                    accept Check;
--                    if WaitingQueue.Get_Size > 0 and WaitingQueue.Get_Size < 1000 then
--                       for item in 1 .. WaitingQueue.Get_Size loop
--                          WaitingQueue.Dequeue (Local_Message);
--                          Put_Line("WaitingQueuesize: " & WaitingQueue.Get_Size'Image);
--
--                          -- if the path is found, send it
--                          if Local_Table (Local_Message.Destination).Dis = 10000 then
--                             --                          Put_Line("Path not found, resending message from " & Local_Message.Sender'Image & " to " & Local_Message.Destination'Image);
--                             for element of Port_List loop
--                                if element.Id = Local_Table (Local_Message.Destination).Next then
--                                   -- send the message
--                                   select
--                                      element.Link.all.Pass_Message (Local_Message);
--                                      --                                   Put_Line (Task_Id'Image & "resend to" & Local_Routing_Table (Message_Hold.Destination).Next_Hop'Image);
--                                   or
--                                      delay 0.001;
--                                      WaitingQueue.Enqueue (Local_Message);
--                                   end select;
--                                end if;
--                             end loop;
--                          else
--                             WaitingQueue.Enqueue (Local_Message);
--                          end if;
--                       end loop;
--                    end if;
--                 or
--                    delay 0.001;
--                 end select;
--
--              end Message_Check;


            task body Update is
               Update_Message : Messages_Table;
               closed : Boolean := False;
            begin
               loop
                  select
                     accept Send;
                     Update_Message.Sender := Task_Id;
                     Update_Message.Table := Local_Table;

                     for i in Port_List'Range loop
                        select
                           Port_List(i).Link.all.Find_Route(Update_Message);
                        or
                           delay 0.1;
                        end select;
                     end loop;
                  or
                     accept Close_Sender do
                        closed := True;
                     end Close_Sender;
                  end select;

                  exit when closed;
               end loop;
            end Update;
         begin
            -- initialize local table
            Local_Table (Task_Id).Next := Task_Id;
            Local_Table (Task_Id).Dis := 0;
            -- Add neighbors
            for i in Port_List'Range loop
               Local_Table (Port_List (i).Id).Next := Port_List (i).Id;
               Local_Table (Port_List (i).Id).Dis := 1;
               --              Put_Line(Task_Id'Image & "has neighbor " & Port_List (i).Id'Image);
            end loop;

            Init.Start;

--              Put_Line("Task" & Task_Id'Image & " Init Queuesize: " & MailboxQueue.Get_Size'Image);

            loop
               if MailboxQueue.Get_Size > 0 then
                  select
                     accept Receive_Message (Message : out Messages_Mailbox) do
                        MailboxQueue.Dequeue (Message);
                        --                          Put_Line ("From" &  Messageage.Sender'Image & " to " & Task_Id'Image & " steps: " & Message.Hop_Counter'Image);
                     end Receive_Message;
                  or
                     delay 0.001;
                  end select;

               end if;

               if WaitingQueue.Get_Size > 0 then
                  for item in 1 .. WaitingQueue.Get_Size loop
                     WaitingQueue.Dequeue (Local_Message);

                     -- if the path is found, send it
                     if Local_Table (Local_Message.Destination).Dis /= 10000 then
                        --                          Put_Line("Path not found, resending message from " & Local_Message.Sender'Image & " to " & Local_Message.Destination'Image);
                        for element of Port_List loop
                           if element.Id = Local_Table (Local_Message.Destination).Next then
                              -- send the message
                              select
                                 element.Link.all.Pass_Message (Local_Message);
                                 --                                   Put_Line (Task_Id'Image & "resend to" & Local_Routing_Table (Message_Hold.Destination).Next_Hop'Image);
                              or
                                 delay 0.001;
                                 WaitingQueue.Enqueue (Local_Message);
                              end select;
                              exit;
                           end if;
                        end loop;
                     else
                        WaitingQueue.Enqueue (Local_Message);
                     end if;
                  end loop;

               end if;

               select
                  accept Find_Route (Message : Messages_Table) do
                     declare
                        Neighbor_To_Destination : Natural;
                        Calculate_Distance      : Natural;
                     begin
--                          Put_Line (Task_Id'Image & "find_route" );
                        for index in Message.Table'Range loop
--                             Put_Line (Task_Id'Image & "forind_route to " & index'Imageage & " " & Message.Table (index).Dis'Image);
                           if Message.Table (index).Dis /= 10000 then
--                                Put_Line (Task_Id'Image & "tries to check route to" & index'Image);
                              Neighbor_To_Destination := Message.Table (index).Dis;
                              Calculate_Distance := 1 + Neighbor_To_Destination;

                              if Local_Table (index).Dis = 10000 or else Local_Table (index).Dis > Calculate_Distance then
                                 Local_Table (index).Dis := Calculate_Distance;
                                 Local_Table (index).Next := Message.Sender;
                                 Is_Updated := True;
--                                   Put_Line (Task_Id'Image & "find anotherther path" & Message.Sender'Image & " to" & index'Image);
                              end if;
                           end if;
                        end loop;
                     end;

                  end Find_Route;
               or
                  accept Send_Message (Message : in Messages_Client) do
--                       Put_Line(Task_Id'Image & " gets send messages");
                     declare
                        Swallow_Message : Messages_Client := Message;
                     begin

--                          Put_Line(Task_Id'Image & " received a call and would like to gett in touch with " & Swallow_Message.Destination'Image);
                        if Task_Id = Swallow_Message.Destination then
--                             Put_Line(Task_Id'Image & " would like to get in touch with " & Swallow_Message.Destination'Image);
                           Mailbox_Message.Sender := Task_Id;
                           Mailbox_Message.The_Message := Swallow_Message.The_Message;
                           Mailbox_Message.Hop_Counter := 0;
--                             Put_Line (Task_Id'Image);
                           -- And local message to local queue
                           MailboxQueue.Enqueue(Mailbox_Message);
--                             Put_Line(Task_id'Image & " Gets messages from: " & Mailbox_Messagesage.Sender'Image);

                        elsif Task_Id /= Swallow_Message.Destination then
--                             Put_Line(Task_Id'Image & " would like to get in touch with " & Swallow_Message.Destination'Image);
                           if Local_Table (Swallow_Message.Destination).Dis = 10000 then
                              Local_Message.Sender      := Task_Id;
                              Local_Message.Destination := Swallow_Message.Destination;
                              Local_Message.The_Message := Swallow_Message.The_Message;
                              Local_Message.Hop_Counter := 0;
                              WaitingQueue.Enqueue (Local_Message);
--                                Put_Line(Task_id'Image & " 2Gets messages from: " & Mailbox_Message.Senderender'Image);
--                                Put_Line("2Queuesize: " & WaitingQueue.Get_Size'Image);
--                                Put_Linene (Task_Id'Image);
                           else
--                                Local_Message.Sender      := Task_Id;
--                                Local_Message.Destination := Swallow_Message.Destination;
--                                Local_Message.The_Message := Swallow_Message.The_Message;
--                                Local_Message.Hop_Counter := 1;
--                                WaitingQueue.Enqueue (Local_Message);
--                                Put_Line(Task_id'Image & " 3Gets messages from: " & Mailbox_Message.Sender'Imageage);
                              declare
                                 Temp_Message : Messages_R;
                              begin
                                 Temp_Message.Destination := Swallow_Message.Destination;
                                 Temp_Message.The_Message := Swallow_Message.The_Message;
                                 Temp_Message.Hop_Counter := 1;
                                 Temp_Message.Sender      := Task_Id;

                                 for element of Port_List loop
                                    if element.Id = Local_Table (Swallow_Message.Destination).Next then
--                                         Put_Line(Task_Id'Image & " found the next touter is " & element.Id'Image);
                                       select
                                          element.Link.all.Pass_Message (Temp_Message);
                                       or
                                          delay 0.001;
                                          WaitingQueue.Enqueue (Temp_Message);
--                                            Put_Line("3Queuesize: " & WaitingQueue.Get_Size'Image);
                                       end select;
                                    end if;
                                 end loop;
                              end;
                           end if;
                        end if;
                     end;
                  end Send_Message;
               or
                  accept Pass_Message (Message : out Messages_R) do
--                       Put_Line(Task_Id'Image & " getets the message from " & Message.Sender'Image);
                     if Task_Id = Message.Destination then
--                          Put_Line("Find the Destinationnation!");
                        Mailbox_Message.The_Message := Message.The_Message;
                        Mailbox_Message.Sender      := Message.Sender;
                        Mailbox_Message.Hop_Counter := Message.Hop_Counter;
                        MailboxQueue.Enqueue(Mailbox_Message);
--                          Put_Line("4Queuesize: " & MailboxQueue.Get_Size'Image);

                     elsif Task_Id /= Message.Destination then
                        if Local_Table (Message.Destination).Dis = 10000 then
                           WaitingQueue.Enqueue (Message);
--                             Put_Line("5Queuesize: " & WaitingQueue.Get_Size'Image);
                        else
                           Message.Hop_Counter := Message.Hop_Counter + 1;
--                             WaitingQueue.Enqueue (Message);
                           for element of Port_List loop
                              if element.Id = Local_Table (Message.Destination).Next then
                                 --                                         Put_Line(Task_Id'Image & " found the next touter is " & element.Id'Image);
                                 select
                                    element.Link.all.Pass_Message (Message);
                                 or
                                    delay 0.02;
                                    WaitingQueue.Enqueue (Message);
                                    --                                            Put_Line("3Queuesize: " & WaitingQueue.Get_Size'Image);
                                 end select;
                              end if;
                           end loop;
--                             Put_Line("6Queuesize: " & WaitingQueue.Get_Size'Image);
                        end if;
                     end if;
                  end Pass_Message;
--                 or
--                    accept Receive_Message (Message : out Messages_Mailbox) do
--                       declare
--                          Made_Up_Mailbox_Message : Messages_Mailbox :=
--                            (Sender      => Task_Id,
--                             The_Message => Message_Strings.To_Bounded_String ("I just see things"),
--                             Hop_Counter => 0);
--                          Temp_Message : Messages_Mailbox;
--                       begin
--
--                          if MailboxQueue.Get_Size > 0 then
--                             select
--                                MailboxQueue.Dequeue (Temp_Message);
--                                Made_Up_Mailbox_Message.Hop_Counter := Temp_Message.Hop_Counter;
--                                Message := Made_Up_Mailbox_Message;
--                                Put_Line( Task_Id'Image & " Received from " & Made_Up_Mailbox_Message.Sender'Image & " using " & Made_Up_Mailbox_Message.Hop_Counter'Image & " steps");
--                             or
--                                delay 0.001;
--                             end select;
--
--                          end if;
--
--                       end;
--                    end Receive_Message;

               or
                  accept Shutdown do
                     Is_Shutdown := True;
                     Update.Close_Sender;
                  end Shutdown;
               or
                  delay 0.001;
               end select;

               exit when Is_Shutdown;




               if Is_Updated then
                  Is_Updated := False;
--                    Put_Line (Task_Id'Image & " is going do update!");
                  select
                     Update.Send;
                  or
                     delay 0.001;
                     Is_Updated := True;
                  end select;
               end if;


--                 if Is_Updated then
--                    Is_Updated := False;
--                    select
--                       Update.Send;
--                    or
--                       delay 0.1;
--                       Is_Updated := True;
--                    end select;
--                 end if;

            end loop;

         end;

      exception
         when Exception_Id : others => Show_Exception (Exception_Id);
      end;

   end Router_Task;

end Generic_Router;
