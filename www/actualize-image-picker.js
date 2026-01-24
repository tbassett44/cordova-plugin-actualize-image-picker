/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/

const DEFAULT_MODULE = "ActualizeImagePicker"

function createCordovaFunction(actionName, module = DEFAULT_MODULE) {
  return (successCallback, errorCallback, options) => {
    console.log(
      "===\n \n" +
      "[INFO] ActualizeImagePicker - Calling Plugin" +
      `\n• Action: ${actionName}` +
      "\n• Options:"+
      `\n${JSON.stringify(options, null, 2)}\n  \n  `
    );

    cordova.exec(successCallback, errorCallback, module, actionName, (options ? [options] : []));
  };
}
  
function createCordovaPromise(actionName, module = DEFAULT_MODULE) {
  const cordovaFunction = createCordovaFunction(actionName, module)
  return (options) => {
    return new Promise((resolve, reject) => cordovaFunction(resolve, reject, options))
  }
}

var API = {
  pickImage: createCordovaPromise("pickImage"),
  pickImages: createCordovaPromise("pickImages")
};

module.exports = API;