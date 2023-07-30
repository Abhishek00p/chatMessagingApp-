import 'package:chatmassegeapp/Auth/login.dart';
import 'package:chatmassegeapp/Firebase/firebase.dart';
import 'package:chatmassegeapp/getControllers/userListController.dart';
import 'package:chatmassegeapp/models/chatModel.dart';
import 'package:chatmassegeapp/models/chatRoomModel.dart';
import 'package:chatmassegeapp/models/userModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'chat.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String userNAME = "";


  getUserName() async {

    print("Curruser Id :${FirebaseAuth.instance.currentUser!.uid}");
    var result = await FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();

    var userDataResult =   result.data();
    print("user Details :${userDataResult?.keys.toList()}  ${userDataResult?.values.toList()}");

    setState(() {
      userNAME= userDataResult?["name"];

    });

  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getUserName();
    MyFirebase().updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      MyFirebase().updateOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    final userListController = Get.put(UserListController());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
              onPressed: () async {
                await MyFirebase().signOut();
                Get.delete<UserListController>();

                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) => LoginPage()));
              },
              icon: Icon(
                Icons.logout_outlined,
                color: Colors.white,
              ))
        ],
        title: Text(
          "HomePage",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: Container(
        height: h,
        width: w,
        child:
            // Obx(
            //   () =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 10,
            ),
            Text("Hello, $userNAME ").marginSymmetric(horizontal: 25,vertical: 10),

            Container(
              height: h * 0.08,
              width: w,
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.all(15),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8), color: Colors.orange),
              child: TextField(
                decoration: InputDecoration(hintText: "Search Here"),
                onChanged: (value) {
                  if (value.isEmpty) {
                    userListController.searchTextEmpty.value = true;
                  } else {
                    userListController.searchTextEmpty.value = false;
                    userListController.listOfUSerNAmes.value =
                        userListController.listOFUSer.value
                            .where((element) => element.name
                                .toString()
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                  }
                },
              ),
            ),
            StreamBuilder(
              stream: MyFirebase().getAllUserList(),
              builder: (context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return SizedBox();
                }

                final usersDocs = snapshot.data!.docs;

                var userList = usersDocs
                    .map((e) =>
                        UserModel.fromJson(e.data() as Map<String, dynamic>))
                    .toList();

                if (FirebaseAuth.instance.currentUser != null) {
                  userList.removeWhere((element) =>
                      element.id == FirebaseAuth.instance.currentUser!.uid);
                }

                userListController.listOFUSer.value = userList;
                return Visibility(
                  visible: !userListController.searchTextEmpty.value,
                  child: Container(
                    padding: EdgeInsets.all(8.0),
                    color: Colors.grey[200],
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount:
                          userListController.listOfUSerNAmes.value.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            var userID =
                                userListController.listOfUSerNAmes[index].id;
                            var currUSerID =
                                FirebaseAuth.instance.currentUser!.uid;
                            var sortedlist = [userID, currUSerID]..sort();

                            Get.to(() => ChatPage(
                                chatRoomId: sortedlist.join("-"),
                                receiverID: userID,
                                receiverName: userListController.listOfUSerNAmes[index].name,
                                participants: sortedlist));
                          },
                          child: ListTile(
                            title: Text(userListController
                                    .listOfUSerNAmes.value[index].name ??
                                ""),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
              stream: MyFirebase().getAllChatRoomList(),
              builder: (context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.data!.docs.isEmpty) {
                  return SizedBox();
                }
                final List usersDocs = snapshot.data!.docs;
                //
                final chatroomList = usersDocs
                    .map((e) =>
                        ChatRoom.fromJson(e.data() as Map<String, dynamic>))
                    .toList();
                return Container(
                  height: h * 0.7,
                  width: w,
                  child: ListView.builder(
                      itemCount: chatroomList.length,
                      itemBuilder: (context, index) {
                        var currUSerID = FirebaseAuth.instance.currentUser!.uid;
                        var isCurrentUserFirstParticipant =
                            chatroomList[index].participants!.first ==
                                currUSerID;
                        var userID = isCurrentUserFirstParticipant
                            ? chatroomList[index].participants!.last
                            : chatroomList[index].participants!.first;
                        var userName = isCurrentUserFirstParticipant
                            ? chatroomList[index].user2Name
                            : chatroomList[index].user1Name;
                        print("user receiver name : $userName");
//
                        var unReadcount = isCurrentUserFirstParticipant
                            ? chatroomList[index].unreadCountOfUser1
                            : chatroomList[index].unreadCountOfUser2;

                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: InkWell(
                            onTap: () {
                              Get.to(() => ChatPage(
                                    chatRoomId: chatroomList[index].chatroomId,
                                    receiverID:userID,
                                    receiverName:userName,
                                    participants:
                                        chatroomList[index].participants,
                                  ));
                            },
                            child: Container(
                              height: h * 0.1,
                              width: w,
                              decoration: BoxDecoration(border: Border.all()),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  CircleAvatar(
                                    radius: w * 0.06,
                                    backgroundColor: Colors.red,
                                  ),
                                  Container(
                                    width: w * 0.55,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text(userName ?? ""),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            Text(chatroomList[index]
                                                    .lastMessage ??
                                                ""),
                                            unReadcount == 0
                                                ? SizedBox()
                                                : CircleAvatar(
                                                    radius: 10,
                                                    child: Center(child: Text("$unReadcount")),
                                                  )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(DateFormat('h:mm a').format(
                                      chatroomList[index]
                                          .lastMessageTimestamp!
                                          .toDate())),
                                  Text("time")
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                );
              },
            )),
          ],
        ),
        // ),
      ),
    );
  }
}

/*

  Expanded(
                child: StreamBuilder<QuerySnapshot>(
              stream: MyFirebase().getAllUserList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final usersDocs = snapshot.data!.docs;

                    final userList  = usersDocs.map((e) => UserModel.fromJson(e.data() as Map<String,dynamic>)).toList();
                return ListView.builder(
                    itemCount: userList.length,
                    itemBuilder: (context, index) {

                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: InkWell(
                          onTap: () {
                            Get.to(() => ChatPage());
                          },
                          child: Container(
                            height: h * 0.1,
                            width: w,
                            decoration: BoxDecoration(border: Border.all()),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                CircleAvatar(
                                  radius: w * 0.06,
                                  backgroundColor: Colors.red,
                                ),
                                Container(
                                  width: w * 0.55,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(userList[index].name??""),
                                      Text("${userList[index].email}"),
                                    ],
                                  ),
                                ),
                                Text("12:15 AM")
                              ],
                            ),
                          ),
                        ),
                      );
                    });
              },
            )),
 */
