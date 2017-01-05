# CareKit + ZeroKit Sample

This repository contains an example iOS application for using CareKit and [ZeroKit](https://tresorit.com/zerokit/carekit.html) together. The sample demonstrates ZeroKit user authentication, data encryption and sharing in a healthcare app.

You can find the original CareKit [readme here](README-CareKit.md).


# What is ZeroKit?

[ZeroKit](https://tresorit.com/zerokit/carekit.html) is a simple, breach-proof user authentication and end-to-end encryption library.

You can find the ZeroKit iOS SDK repository on GitHub [here](https://github.com/tresorit/ZeroKit-iOS-SDK). We suggest you get to know the ZeroKit SDK and its usage a little before continueing with this sample app. 


# Getting Started

To run the sample app you will need to set up a few things first. Follow the steps we provided here.

## Requirements

* Xcode 8.1+
* iOS 9.0+

## 1. Configuring ZeroKit

If you downloaded this sample with the script from the ZeroKit admin portal, then ZeroKit is already configured for you and you can jump to **2. Configuring the App ID**.

In the `ZeroKitSample/CareKitZeroKitSample/ExampleAppMock.plist` set the values for `ZeroKitAPIURL`, `AdminUserId`, `AdminKey` and `ApiRoot` (tenant URL). You will find the values in your ZeroKit admin portal. If this file does not exist then copy the sample `ExampleAppMock.sample.plist` file in the same directory to create one:

```xml
<key>ZeroKitAPIURL</key>
<string>https://host-{hostid}.api.tresorit.io/tenant-{tenantid}/static/v4/api.html</string>
<key>AdminUserId</key>
<string>admin@{tenantid}.tresorit.io</string>
<key>AdminKey</key>
<string>{adminkey}</string>
<key>ApiRoot</key>
<string>https://host-{hostid}.api.tresorit.io/tenant-{tenantid}</string>
```

## 2. Configuring the App ID

Since the example uses CloudKit it takes some setting up. If you used CloudKit before, then this will be familiar to you.

1. You should have an active Apple Developer subscription as the sample app uses CloudKit to store data.
2. Add an iCloud container to store the sample app data [here](https://developer.apple.com/account/ios/identifier/cloudContainer).
    * The app uses the default CloudKit container, so it should match the App ID you will use in *Step 3*. For example, if your app ID is `com.mycompany.myapp`, the matching default iCloud container ID is `iCloud.com.mycompany.myapp`.
3. Create new or edit an existing app ID and enable **HealthKit** and **iCloud** services for it [here](https://developer.apple.com/account/ios/identifier/bundle).
    1. To enable the services on an existing App ID click the *Edit* button then enable **HealthKit** and **iCloud (with CloudKit support)** in the list.
    2. Next to the iCloud service tap the edit button. Here you can assign the iCloud container created in *step 2*. Select it and tap *Continue*.
    3. Now you have enabled HealthKit and iCloud services, and also specified the iCloud container. You can click click *Done*.
    4. Provisioning profile:
        * If you have an existing provisioning profile for the App ID, then you will have to regenerate it after the changes. Click *Edit* on the profile then click *Generate*. Make sure to download the profile to use the latest version.
        * If you create a new profile then just select the previous App ID and use that.
4. Open the `CKWorkspace.xcworkspace` in this repository and select the `CareKitZeroKitSample` project to edit the following properties:
    * On the General tab change the bundle ID for the `CareKitZeroKitSample` app to the app ID you edited in *Step 3*.
    * On the General tab in the *Signing (Debug)* section, select the provisioning profile you created in *Step 3*.
    * Under the Capabilities tab make sure the app uses the default iCloud container you specified in *Step 2*.
5. Make sure you are logged in to iCloud on the device or simulator you will run the app on.
    * In the simulator open *Settings*, select *iCloud*, then log in with an Apple ID.
    * To create a new Apple ID open *System Preferences* on your Mac, select *Internet Accounts*, click *iCloud*, then click *Create Apple ID*.
6. Build and Run the `CareKitZeroKitSample` app
7. You will be able to view the data stored in CloudKit in your [dashboard](https://icloud.developer.apple.com/dashboard/).
    * Be sure to select the iCloud container you specified earlier in the top left corner.
    * To view the data click the *Default Zone* under the *Public Data* section. You may have to click *Add Record ID Query Index* to continue if you are viewing for the first time. (This is necessary because record types were created programatically the first time your ran the sample app.)


# App Usage

The sample app can be used by doctors and patients. Patients use their Care Card and Symptoms Tracker provided by CareKit to record their data and they can share it with doctors to see.

Patients' data is stored locally by CareKit and also stored it in the cloud using Apple's CloudKit. Patient data in the cloud is protected by ZeroKit encryption. Data is first encrypted on the user's device and then saved to the cloud.

## As Doctor

When signing up a new user make sure to have 'Sign up as a doctor' switched *ON*. After successful registration you will be logged in and see these tabs:

* **My Patients**: This is a list of your patients. It will be empty at first. New patients will appear when they share their data with the doctor.
* **Account**: Here you can see the username you are logged in with and can also logout here.

## As Patient

When signing up a new user make sure to have 'Sign up as a doctor' switched *OFF*. After successful registration you will be logged in and see these tabs:

* **Care Card**: This is CareKit's care card.
* **Symptoms**: This is CareKit's symptoms tracker.
* **Insights**: This is CareKit's insights.
* **My Doctors**: Here the patient can see the doctors that they have shared their data with or add new doctors by tapping the **+** button.
* **Account**: Here you can see the username you are logged in with and can also logout here.


# How the Sample App Works

In this section we describe how different parts of the application work, eg. administrative calls, registration, data storing, sharing, encryption, etc.

*Note: The sample app is the `CareKitZeroKitSample` in the `CKWorkspace.xcworkspace`.*

## CareKit Sample Classes

The app uses several classes from the `OCKSample` project. These are under the `OCKSampleClasses` group in the project. If you have previously seen the official CareKit sample app then you should be familiar with these. If not, then you should really take a look at it.

## ZeroKit Sample Classes

The app uses a few classes from the `ZeroKitExample` app project. These are under the `ZeroKitExampleClasses` group in the project.

The `ZeroKitExample` app is the official sample app for the ZeroKit iOS SDK. If you have not yet tried it then you should get familiar with it. The app can be found in this repository under the `ZeroKit` directory, open the `ZeroKit.xcworkspace` to take a look. If you downloaded this sample using the script from the ZeroKit admin portal then this example is already configured for you. Otherwise see the `README.md` next to the workspace about setting up the example.

### Administrative calls

The `ExampleAppMock` class taken from the ZeroKit example app handles the administrative calls. In a normal app these must be handled by your backend. In this sample app we provided a mock implementation so you do not have to set up a backend.

**Important: Admin calls need an admin key that should be kept secret and must not be included in client side applications.**

## User Authentication

ZeroKit is used for the user authentication. The `Authenticator` class handles user registration, login, autologin (rememberMe) and logout.

### Registration

Registration takes three steps. Details are described in the ZeroKit documentation. A brief overview:

1. Registration is initialized with an admin call via the `ExampleAppMock` class. This gives us a **user ID** and two verification identifiers: a **registration session ID** and a **registration session verifier**.
2. User is registered via the ZeroKit SDK using the **user ID** and **registration session ID** received previously and the **password** they entered. This returns a **registration validation verifier**.
3. Registration is verified with an admin call using the **user ID**, **registration session ID**, **registration session verifier** and **registration validation verifier**.
4. The ZeroKit part of the registration is complete. We now save the user's **user ID** and the **username** they typed when they registered to CloudKit.
5. Registration is done. User can log in now.

### Login

#### Login with password
For login the user provides their **username** and **password**. They also specify if the next time they want to be able to log in with Touch ID without typing their password. (Only on devices where Touch ID is available.) We perform these steps:

1. Fetch the ZeroKit **user ID** for the **username** typed by the user from CloudKit.
2. Perform the ZeroKit login using the **user ID** and **password**. We also specify if the user wants to be 'remembered', meaning the next time they can log in without typing their password.
3. After login is successful we set the current user to the logged in user.
4. Login is done. Notification is sent that the user changed.  

#### Autologin (Login by remember me)

If the user specified that they want to be able to log in using Touch ID, they can log in next time without having to type their passwords. We use ZeroKit's `loginByRememberMe` method to log in the user after the app launches and Touch ID verification succeeds. For this only the **user ID** is required and that ZeroKit saved a key for the login.

## GUI

### Login and Registration

The application presents the `WelcomeViewController` after launch. If Touch ID is available the user can be logged in automatically if they specified it when they logged in previously.

User login with password is handled by the `LoginViewController`. User registration is handled by the `RegisterViewController`. The user always types their password into a `ZeroKitPasswordField` so we do not have to handle the password at all, it is handled by the ZeroKit SDK.

### DoctorRootViewController

When a doctor user logs in a `DoctorRootViewController` is presented. It is a tab bar controller and contains the following view controllers:

* `MyPatientsViewController`: It contains the list of patients that shared their data with the doctor. It fetches them from the cloud and populates the list.
* `AccountViewController`: Presents the username and user ID. Also provides the logout functionality.

### PatientRootViewController

When a patient user logs in a `PatientRootViewController` is presented. It is a tab bar controller and contains the following view controllers:

* `OCKCareCardViewController`: See the CareKit documentation.
* `OCKSymptomTrackerViewController`: See the CareKit documentation.
* `OCKInsightsViewController`: See the CareKit documentation.
* `MyDoctorsViewController`: It presents a list of the doctors who the user shared their data with. It is empty by default and the user can add doctors to share their data. They can choose if the only want to share their Care card or Symptoms tracker or both with the doctor. These two things are encrypted using different tresors in ZeroKit so they can be shared separately. Sharing is handled by the `PatientDataShareViewController`.
* `AccountViewController`: It's the same as for the doctors. The user can log out here.


## Storing Data

The app stores data locally and stores data in the cloud. 

The `CarePlanStoreManager` class takes care of managing the local and cloud stores. It also initiates saving local changes to the cloud and updating local data from the cloud. It manages data for a single patient.

### Local Storage

For local storage the app uses CareKit's `OCKCarePlanStore` that provides a Core Data based solution. CareKit's [documentation](http://carekit.org/docs/docs/AccessingCarePlanData/AccessingCarePlanData.html) states that **local data** is protected by the device's encryption: *"CareKit’s database is encrypted using standard file system encryption. Specifically, the database uses NSFileProtectionComplete encryption, which means the database is stored in an encrypted format on disk and cannot be read from or written to while the device is locked or booting."*

### Cloud Storage

For remote storage the app uses Apple's `CloudKit` framework that lets us store data in iCloud. ZeroKit is used to encrypt data stored in the cloud. Data is first encrypted on the device and then saved to the cloud. All patient health data, specifically the `OCKCarePlanActivity` and `OCKCarePlanEvent` objects, are stored encrypted in the cloud. Only doctors specified by the patient are able to decrypt and read the data. 

We encrypt the patient's Care Card and Symptoms Tracker data (the interventions and assessments activities and associated events) in separate ZeroKit tresors. This way they are encrypted with different keys and can be shared separately.

#### CloudKit Record Types

We have the following types in CloudKit:

* **User**: Describes a user of the app. The record ID is the user's username. It stores the ZeroKit user ID and the tresors IDs for the interventions (Care Card) and assessments (Symptoms Tracker) tresors. The corresponding model class is `User`.
* **PatientDataShare**: Describes how a patient shared their data with a doctor. It contains references to a patient and a doctor user, and it stored if interventions and assessments are shared. There is an entry for each doctor the patient shared their data with. The corresponding model class is `PatientDataShare`.
* **CarePlanActivity**: Stores a patient's `OCKCarePlanActivity` data. The data is encrypted, so it can only be read by the patient and the doctors it is shared with. The record also contains a ZeroKit user ID to specify who this data belongs to, and an activity type so we can query for intervention or assessment activities. The corresponding model class is `CloudCarePlanActivity`.
* **CarePlanEvent**: Stores a patient's `OCKCarePlanEvent` data with the corresponding `OCKCarePlanEventResult` if it exists. It is encrypted the same way the `CarePlanActivity` record and has the same additional attributes.

#### CloudKit Manager Classes

CloudKit data fetching and modification is implemented by two classes:

* **CloudKitPatientDataStore**: This class handles the patient's health data provided by CareKit. This includes the activities and the events. These data records that belong to a patient are encrypted when saved to the cloud, and decrypted when fetched from the cloud.  
* **CloudKitStore**: This class handles data in the cloud that is not encrypted by ZeroKit. It includes the `User` and the `PatientDataShare` records. This class also implements a helper method to create the CloudKit record types. It takes advantage of CloudKit's development environment that if a record type or its field does not exist at the time of saving, then it will be automatically created. `CloudKitStore` does this by saving dummy data to the cloud then deleting it, saving you the time to manually create the record types.

### Synchronization

The synchronization of locally stored data and cloud data is performed by the `CloudSync` class. It updates locally updated activities and events in the cloud, and changes in the cloud are saved to the local database.

Synchronization is done using timestamps. Each activity and event has its own modification date. We assume that always the latest modification date is the latest. Synchronization is performed on the activities first then on the events. The sample app fetches all records from the local store and from the cloud store, compares them, then updates them locally and in the cloud as necessary based on the modification date.

Synchronization is automatically scheduled to run. This keeps the data updated when changes in the cloud happen. You could also use push notifications to achive similar behaviour.

***Known issue:*** Some activities may be duplicated in the cloud as CloudKit does not always return recently saved records. As the sample app uses random identifiers for the activity records, these however will not be duplicated in the local database because data is decrypted before saving there. 

## Sharing Data

Data sharing is always initiated by the patient. Sharing is done by the `PatientDataShare` class. This model class contains who the data is shared with, the patient and the doctor user. It also contains which tresors are shared, the sharing state for the interventions and assessments tresors.

Sharing takes the following steps:

1. Tresor is shared using ZeroKit. The patient shares their tresor with the doctor.
2. Sharing must be approved by an administrative call. (Described previously.)
3. The `PatientDataShare` record is updated in the cloud.

***Notice:*** The user of ZeroKit must save the tresor IDs and track who the tresor is shared with. They must also make sure this information is consistent with ZeroKit. In the sample app the sharing state in ZeroKit and CloudKit may become inconsistent if the 3rd step fails. As a 0th step we could save that a sharing will happen so if it fails later we can repeat it to fix it. 

***Notice 2:*** All data is stored in CloudKit public database. Data access management is handled by ZeroKit, this makes sure only authorized users can *read* the data. The CloudKit server does not perform checks who can *read* or *edit* records. Your server should make sure users can only *edit* records they are allowed to. Since CloudKit logic is in the app, in this sample the app takes care of these.

## CareKit Extensions

For the sample app we had to modify CareKit a bit to make synchronizing data with the cloud easier. We added several methods to `OCKCarePlanStore`, eg. to fetch all events or events only for a certain activity type. We added methods to its delegate `OCKCarePlanStoreDelegate` so we know when we are saving data to the local store from the cloud and updates happen because of that, but no synchronization should be triggered. 

# Contact

Contact us at [zerokit@tresorit.com](mailto:zerokit@tresorit.com).

# License

This sample app is available under the license contained in the [ZeroKitSample/LICENSE.txt](ZeroKitSample/LICENSE.txt).

CareKit is available under [Apple's license](LICENSE).

