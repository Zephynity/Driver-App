import 'dart:async';
import 'package:ehatid_driver_app/geofire_assistant.dart';
import 'package:ehatid_driver_app/active_nearby_available_passengers.dart';
import 'package:ehatid_driver_app/profile_tab.dart';
import 'package:ehatid_driver_app/push_notification_system.dart';
import 'package:ehatid_driver_app/select_nearest_active_driver_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'assistant_methods.dart';
import 'global.dart';
import 'login.dart';


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}



class _HomePageState extends State<HomePage>
{
  Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final currentFirebaseUser = FirebaseAuth.instance.currentUser!;

  static final CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(13.7731, 121.0484),
    zoom: 16,
  );

  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();

  var geoLocator = Geolocator();

  LocationPermission? _locationPermission;

  List<LatLng> pLineCoOrdinatesList = [];
  Set<Polyline> polyLineSet = {};

  Set<Marker> markersSet = {};

  bool activeNearbyDriverKeysLoaded = false; //Activedrivers code
  bool activeNearbyPassengerKeysLoaded = false; //Activepassenger code

  List<ActiveNearbyAvailablePassengers> onlineNearbyAvailablePassengersList = [];

  DatabaseReference? referenceRideRequest;


  Future<void> _signOut() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove('initScreen');
    try {
      await _firebaseAuth.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => LoginScreen(),
      ),
      );
    } catch (e) {
      print(e.toString()) ;
    }
  }

  checkIfLocationPermissionAllowed() async
  {
    _locationPermission = await Geolocator.requestPermission();

    if(_locationPermission == LocationPermission.denied)
    {
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  locateUserPosition() async {
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    driverCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);

    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 14);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoordinates(driverCurrentPosition!, context);
    print("this is your address =" + humanReadableAddress);

    AssistantMethods.readDriverRatings(context);

    initializeGeoFireListener(); //Active Drivers
  }

  readCurrentDriverInformation() async
  {
    FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(currentFirebaseUser.uid)
        .once()
        .then((snap)
    {
      if(snap.snapshot.value != null)
      {
        onlineDriverData.id = (snap.snapshot.value as Map)["id"];
        onlineDriverData.first_name = (snap.snapshot.value as Map)["first_name"];
        onlineDriverData.last_name = (snap.snapshot.value as Map)["last_name"];
        onlineDriverData.phone = (snap.snapshot.value as Map)["phone"];
        onlineDriverData.email = (snap.snapshot.value as Map)["email"];
        onlineDriverData.plateNum = (snap.snapshot.value as Map)["plateNum"];
      }
    });

    PushNotificationSystem pushNotificationSystem = PushNotificationSystem();
    pushNotificationSystem.initializeCloudMessaging(context);
    pushNotificationSystem.generateAndGetToken();

    AssistantMethods.readDriverEarnings(context);
  }

  @override
  void initState() {
    super.initState();
    //_setMarker(LatLng(37.42796133580664, -122.085749655962));
    checkIfLocationPermissionAllowed();
    readCurrentDriverInformation();
    //there are active drivers available
    retrieveOnlinePassengersInformation(onlineNearbyAvailablePassengersList);
  }
  

  @override
  Widget build(BuildContext context)
  {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: Color(0xFFFFFCEA)),
      child: new Scaffold(
        backgroundColor: Color(0xFFEBE5D8),
        appBar: AppBar(
          centerTitle: true,
          title: Text("Home"),
          backgroundColor: Color(0xFFFED90F),
        ),
        body: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              initialCameraPosition: _kGooglePlex,
              polylines: polyLineSet,
              markers: markersSet,
              onMapCreated: (GoogleMapController controller) {
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;

                locateUserPosition();
              },
            ),
            //ui for online offline driver
            statusText != "Go Offline"
                ? Container(
              height: MediaQuery.of(context).size.height,
              width: double.infinity,
              color: Colors.black87,
            )
                : Container(),

            //button for online offline driver
            Positioned(
              top: statusText != "Go Offline"
                  ? 40.h
                  : 25,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: ()
                    {
                      if(isDriverActive != true) //offline
                        {
                        //driverIsOnlineNow();
                        //updateDriversLocationAtRealTime();

                        setState(() {
                          statusText = "Go Offline";
                          isDriverActive = true;
                          buttonColor = Colors.transparent;
                          passengerButtonColor = Color(0xFF0CBC8B);
                        });

                        //display Toast
                        Fluttertoast.showToast(msg: "You're Now Online");
                      }
                      else //online
                      {
                        driverIsOfflineNow();

                        setState(() {
                          statusText = "Go Online";
                          isDriverActive = false;
                          buttonColor = Color(0xFF0CBC8B);
                          passengerButtonColor = Color(0x4D0CBC8B);
                        });

                        //display Toast
                        Fluttertoast.showToast(msg: "You're Now Offline");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: statusText != "Go Offline"
                        ? Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.phonelink_erase_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: statusText != "Go Offline"
                  ? 20.h
                  : 20.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: ()
                    {
                      if(isDriverActive != true) //offline
                      {
                        Fluttertoast.showToast(msg: "You're Still Offline");
                      }
                      else
                      {
                        onlineNearbyAvailablePassengersList = GeoFireAssistant.activeNearbyAvailablePassengersList;
                        searchNearestOnlineDrivers();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: passengerButtonColor,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: statusText != "Go Offline"
                        ? Text(
                      "Passenger",
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9E9E9E4D),
                      ),
                    )
                        : Text(
                      "Passenger",
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  //Section 17: Para Mapalabas ang ACTIVE
  initializeGeoFireListener() {
    Geofire.initialize("activePassengers");
    Geofire.queryAtLocation(
        driverCurrentPosition!.latitude, driverCurrentPosition!.longitude, 2)!
        .listen((map) {
      print(map);
      if (map != null) {
        var callBack = map['callBack'];

        //latitude will be retrieved from map['latitude']
        //longitude will be retrieved from map['longitude']

        switch (callBack)
            {
          case Geofire.onKeyEntered: //whenever any driver become active or online
            ActiveNearbyAvailablePassengers activeNearbyAvailablePassengers = ActiveNearbyAvailablePassengers();
            activeNearbyAvailablePassengers.locationLatitude = map['latitude'];
            activeNearbyAvailablePassengers.locationLongitude = map['longitude'];
            activeNearbyAvailablePassengers.passengerId = map['key'];
            GeoFireAssistant.activeNearbyAvailablePassengersList.add(activeNearbyAvailablePassengers);
            if(activeNearbyPassengerKeysLoaded == true)
            {
              displayActivePassengersOnUsersMap();
            }
            break;

          case Geofire.onKeyExited: //whenever any driver become non-active or offline
            GeoFireAssistant.deleteOfflinePassengerFromList(map['key']);
            break;

        //whenever the driver moves - update driver location
          case Geofire.onKeyMoved:
            ActiveNearbyAvailablePassengers activeNearbyAvailablePassengers = ActiveNearbyAvailablePassengers();
            activeNearbyAvailablePassengers.locationLatitude = map['latitude'];
            activeNearbyAvailablePassengers.locationLongitude = map['longitude'];
            activeNearbyAvailablePassengers.passengerId = map['key'];
            GeoFireAssistant.updateActiveNearbyAvailableDriveLocation(activeNearbyAvailablePassengers);
            displayActivePassengersOnUsersMap();
            break;

        //display those online drivers on users map
          case Geofire.onGeoQueryReady:
            displayActivePassengersOnUsersMap();
            break;
        }
      }

      setState(() {});
    });
  }

  searchNearestOnlineDrivers() async
  {
    //no active driver available
    if(onlineNearbyAvailablePassengersList.length == 0)
    {
      //cancel/delete the ride request
      //referenceRideRequest!.remove();

      setState(() {
        polyLineSet.clear();
        markersSet.clear();
        pLineCoOrdinatesList.clear();
      });

      Fluttertoast.showToast(msg: "No Online Nearby Passengers");
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (c)=> SelectNearestActiveDriversScreen()));
    //
    // if(response == "passengerChoosed")
    // {
    //   FirebaseDatabase.instance.ref()
    //       .child("passengers")
    //       .child(chosenPassengerId!)
    //       .once()
    //       .then((snap)
    //   {
    //     if(snap.snapshot.value != null)
    //     {
    //       //send notification to that specific driver
    //       sendNotificationToDriverNow(chosenPassengerId!);
    //
    //       //Display Waiting Response from a Driver UI
    //       //showWaitingResponseFromDriverUI();
    //
    //       //Response from the driver
    //       FirebaseDatabase.instance.ref()
    //           .child("passengers")
    //           .child(chosenPassengerId!)
    //           .child("newRideStatus")
    //           .onValue.listen((eventSnapshot)
    //       {
    //         //driver can cancel the RideRequest Push Notifications
    //         //(newRideStatus = idle)
    //         if(eventSnapshot.snapshot.value == "idle")
    //         {
    //           Fluttertoast.showToast(msg: "The driver has cancelled your request. Please choose another driver.");
    //
    //           Future.delayed(const Duration(milliseconds: 3000), ()
    //           {
    //             Fluttertoast.showToast(msg: "Please Restart app now.");
    //
    //             SystemNavigator.pop();
    //           });
    //         }
    //
    //         //accept the ride request push notification
    //         //(newRideStatus = accepted)
    //         if(eventSnapshot.snapshot.value == "accepted")
    //         {
    //           //send notif t
    //         }
    //       });
    //     }
    //     else
    //     {
    //       Fluttertoast.showToast(msg: "This driver do not exist. Try again.");
    //     }
    //   });
    // }
  }

  sendNotificationToDriverNow(String chosenPassengerId)
  {
    //assign RideRequestId to newRideStatus in Drives Parent node for that specific chosen driver
    FirebaseDatabase.instance.ref()
        .child("passengers")
        .child(chosenPassengerId!)
        .child("newRideStatus")
        .set(referenceRideRequest!.key);

    //automate the push notifications
    FirebaseDatabase.instance.ref()
        .child("passengers")
        .child(chosenPassengerId!)
        .child("token")
        .once().then((snap)
    {
      if(snap.snapshot.value != null)
      {
        String deviceRegistrationToken = snap.snapshot.value.toString();

        //send notification now
        AssistantMethods.sendNotificationToDriverNow(
          deviceRegistrationToken,
          referenceRideRequest!.key.toString(),
          context,
        );

        Fluttertoast.showToast(msg: "Notification sent successfully.");
      }
      else
      {
        Fluttertoast.showToast(msg: "Please choose another driver.");
        return;
      }
    });

  }

  retrieveOnlinePassengersInformation(List onlineNearestPassengersList) async
  {
    DatabaseReference ref = FirebaseDatabase.instance.ref().child("passengers");
    for(int i = 0; i<onlineNearestPassengersList.length; i++)
    {
      await ref.child(onlineNearestPassengersList[i].passengerId.toString())
          .once()
          .then((dataSnapshot)
      {
        var passengerKeyInfo = dataSnapshot.snapshot.value;
        setState(() {
          dList.add(passengerKeyInfo);
        });
        print("passengerKey Info: " + dList.toString());
      });
    }
  }


  displayActivePassengersOnUsersMap()
  {
    setState(() {
      markersSet.clear();

      Set<Marker> driversMarketSet = Set<Marker>();

      for(ActiveNearbyAvailablePassengers eachPassenger in GeoFireAssistant.activeNearbyAvailablePassengersList)
      {
        LatLng eachPassengerActivePosition = LatLng(eachPassenger.locationLatitude!, eachPassenger.locationLongitude!);

        Marker marker = Marker(
          markerId: MarkerId(eachPassenger.passengerId!),
          position: eachPassengerActivePosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: 360,
        );

        driversMarketSet.add(marker);
      }

      setState(() {
        markersSet = driversMarketSet;
      });
    });
  }

/***
  driverIsOnlineNow() async
  {
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    driverCurrentPosition = pos;

    Geofire.initialize("activeDrivers");

    Geofire.setLocation(
        currentFirebaseUser.uid,
        driverCurrentPosition!.latitude,
        driverCurrentPosition!.longitude
    );

    DatabaseReference ref = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(currentFirebaseUser.uid)
        .child("newRideStatus");

    ref.set("idle"); //searching for ride request
    ref.onValue.listen((event) { });
  }

  updateDriversLocationAtRealTime()
  {
    streamSubscriptionPosition = Geolocator.getPositionStream()
        .listen((Position position)
    {
      driverCurrentPosition = position;

      if(isDriverActive == true)
      {
        Geofire.setLocation(
            currentFirebaseUser.uid,
            driverCurrentPosition!.latitude,
            driverCurrentPosition!.longitude
        );
      }

      LatLng latLng = LatLng(
        driverCurrentPosition!.latitude,
        driverCurrentPosition!.longitude,
      );

      newGoogleMapController!.animateCamera(CameraUpdate.newLatLng(latLng));
    });
  }
***/

  driverIsOfflineNow()
  {
    Geofire.removeLocation(currentFirebaseUser.uid);

    DatabaseReference? ref = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(currentFirebaseUser.uid)
        .child("newRideStatus");
    ref.onDisconnect();
    ref.remove();
    ref = null;
  }
}