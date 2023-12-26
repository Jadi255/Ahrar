importScripts('https://www.gstatic.com/firebasejs/8.4.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.4.1/firebase-messaging.js');

const firebaseConfig = {
    apiKey: "AIzaSyC9sqehoMNAfcfXAd9VUJR4A8HWr3raonc",
    authDomain: "ahrar-app.firebaseapp.com",
    projectId: "ahrar-app",
    storageBucket: "ahrar-app.appspot.com",
    messagingSenderId: "519776664484",
    appId: "1:519776664484:web:0d60b4b9dfd5331d065f31",
    measurementId: "G-KR16H61D5E"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('Received background message ', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
    };

    self.registration.showNotification(notificationTitle,
        notificationOptions);
});
