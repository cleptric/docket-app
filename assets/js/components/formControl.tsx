import React from 'react';
import classnames from 'classnames';

import {ValidationErrors} from 'app/types';
import FormError from 'app/components/formError';

type InputAttrs = Pick<Props, 'name' | 'id' | 'required'>;

type InputType = 'text' | 'email' | 'password' | ((attrs: InputAttrs) => React.ReactNode);

type Props = {
  name: string;
  label: React.ReactNode;
  type: InputType;
  id?: string;
  required?: boolean;
  help?: React.ReactNode;
  errors?: ValidationErrors;
};

function FormControl({
  name,
  id,
  label,
  help,
  errors,
  required,
  type,
}: Props): JSX.Element {
  id = id ?? name;

  let input: React.ReactNode;
  if (typeof type === 'string') {
    input = <input id={id} name={name} type={type} required={required} />;
  } else if (typeof type === 'function') {
    const inputAttrs = {name, id, required};
    input = type(inputAttrs);
  }
  const className = classnames('form-input', {
    'is-error': errors && errors[name] !== undefined,
  });

  return (
    <div className={className}>
      <label htmlFor={id}>
        {label}
        {help && <p className="form-help">{help}</p>}
      </label>
      <div>
        {input}
        <FormError errors={errors} field={name} />
      </div>
    </div>
  );
}

export default FormControl;
