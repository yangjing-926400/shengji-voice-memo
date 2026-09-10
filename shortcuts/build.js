const fs = require('fs');
const { actionOutput, buildShortcut, withVariables } = require('@joshfarrant/shortcuts-js');

function withActionOutput(builder) {
  return (options, output) => {
    const action = builder(options);
    if (output) {
      action.WFWorkflowActionParameters.UUID = output.Value.OutputUUID;
      if (output.Value.OutputName) action.WFWorkflowActionParameters.CustomOutputName = output.Value.OutputName;
    }
    return action;
  };
}

const dictateText = withActionOutput(() => ({
  WFWorkflowActionIdentifier: 'is.workflow.actions.dictatetext',
  WFWorkflowActionParameters: {
    DictateTextLanguage: 'zh-CN',
    DictateTextStopListening: 'Time'
  }
}));

const makeURL = ({ url = '' }) => ({
  WFWorkflowActionIdentifier: 'is.workflow.actions.url',
  WFWorkflowActionParameters: { WFURLActionURL: url }
});

const openURLs = () => ({
  WFWorkflowActionIdentifier: 'is.workflow.actions.openurl',
  WFWorkflowActionParameters: {}
});

const dictated = actionOutput('听写文字');
const encoded = actionOutput('编码后的文字');
const target = process.argv[2] || 'https://example.com/';
const makeTarget = (encodedText) => withVariables([target + '?shortcutText=', ''], encodedText);

const actions = [
  dictateText({}, dictated),
  {
    WFWorkflowActionIdentifier: 'is.workflow.actions.urlencode',
    WFWorkflowActionParameters: {
      WFEncodeMode: 'Encode',
      UUID: encoded.Value.OutputUUID,
      CustomOutputName: encoded.Value.OutputName
    }
  },
  makeURL({ url: makeTarget(encoded) }),
  openURLs()
];

fs.writeFileSync(process.argv[3] || 'shengji-unsigned.shortcut', buildShortcut(actions, {
  icon: { color: 4282601983, glyph: 59446 },
  showInWidget: true
}));
